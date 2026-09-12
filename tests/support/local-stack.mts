// Test-only HTTP adapter: real PostgreSQL, authenticated RLS and RPCs.
// It substitutes Supabase Auth/PostgREST transport, never application auth checks.
import { createServer } from "node:http";
import { spawn, execFileSync } from "node:child_process";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createHmac } from "node:crypto";
import pg from "pg";
// PostgREST serializes PostgreSQL numeric as JSON numbers; pg defaults to strings.
pg.types.setTypeParser(1700, Number);
const root = mkdtempSync(join(tmpdir(), "gymtracker-browser-"));
const socket = join(root, "socket");
mkdirSync(socket);
let started = false;
process.once("exit", () => {
  if (started) {
    execFileSync(
      "pg_ctl",
      ["-D", join(root, "data"), "stop", "--mode", "fast"],
      { stdio: "ignore" },
    );
  }
  rmSync(root, { recursive: true, force: true });
});
const users = [
  {
    id: "30000000-0000-0000-0000-000000000001",
    email: "browser-a@example.test",
  },
  {
    id: "30000000-0000-0000-0000-000000000002",
    email: "browser-b@example.test",
  },
];
const secret = "local-test-only-signature-never-a-production-secret";
const sign = (user: (typeof users)[number]) => {
  const payload = Buffer.from(
    JSON.stringify({
      sub: user.id,
      email: user.email,
      role: "authenticated",
      aud: "authenticated",
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600,
    }),
  ).toString("base64url");
  const content =
    Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString(
      "base64url",
    ) +
    "." +
    payload;
  return (
    content +
    "." +
    createHmac("sha256", secret).update(content).digest("base64url")
  );
};
function identify(token: string) {
  return users.find((u) => {
    const parts = token.split(".");
    if (
      parts.length !== 3 ||
      createHmac("sha256", secret)
        .update(parts[0] + "." + parts[1])
        .digest("base64url") !== parts[2]
    )
      return false;
    const claims = JSON.parse(Buffer.from(parts[1], "base64url").toString());
    return claims.sub === u.id && claims.exp > Date.now() / 1000;
  });
}
const asUser = (u: (typeof users)[number]) => ({
  ...u,
  aud: "authenticated",
  role: "authenticated",
  app_metadata: { provider: "email" },
  user_metadata: {},
  created_at: new Date().toISOString(),
});
execFileSync(
  "initdb",
  ["-D", join(root, "data"), "--auth=trust", "--no-locale"],
  { stdio: "ignore" },
);
execFileSync(
  "pg_ctl",
  [
    "-D",
    join(root, "data"),
    "-l",
    join(root, "postgres.log"),
    "-o",
    "-F -c listen_addresses='' -k " + socket,
    "start",
  ],
  { stdio: "ignore" },
);
started = true;
const pool = new pg.Pool({ host: socket, database: "postgres" });
await pool.query(
  readFileSync("scripts/test-support/supabase-bootstrap.sql", "utf8"),
);
for (const file of readdirSync("supabase/migrations")
  .filter((f) => f.endsWith(".sql"))
  .sort())
  await pool.query(readFileSync(join("supabase/migrations", file), "utf8"));
for (const u of users)
  await pool.query("insert into auth.users(id,email) values($1,$2)", [
    u.id,
    u.email,
  ]);
const tables = new Set([
  "exercises",
  "routines",
  "routine_exercises",
  "workouts",
  "workout_exercises",
  "workout_sets",
]);
const identifier = (s: string) => {
  if (!/^[a-z_]+$/.test(s)) throw new Error("Bad identifier");
  return '"' + s + '"';
};
const api = createServer(async (req, res) => {
  res.setHeader("content-type", "application/json");
  const send = (status: number, body: unknown) => {
    res.statusCode = status;
    res.end(JSON.stringify(body));
  };
  let client: pg.PoolClient | undefined;
  try {
    const url = new URL(req.url!, "http://127.0.0.1:54329");
    if (process.env.TEST_HTTP_DEBUG) console.log(req.method, url.pathname);
    const chunks: Buffer[] = [];
    for await (const chunk of req) chunks.push(chunk);
    const body = chunks.length
      ? JSON.parse(Buffer.concat(chunks).toString())
      : {};
    if (url.pathname === "/auth/v1/token" && req.method === "POST") {
      const user = users.find((u) => u.email === body.email);
      if (!user || body.password !== "Test-password-123")
        return send(400, {
          code: "invalid_credentials",
          msg: "Invalid credentials",
        });
      return send(200, {
        access_token: sign(user),
        token_type: "bearer",
        expires_in: 3600,
        refresh_token: "test-refresh",
        user: asUser(user),
      });
    }
    const user = identify(
      (req.headers.authorization ?? "").replace(/^Bearer /, ""),
    );
    if (!user) return send(401, { message: "Authentication required" });
    if (url.pathname === "/auth/v1/user") return send(200, asUser(user));
    if (url.pathname === "/auth/v1/logout") return send(200, {});
    client = await pool.connect();
    await client.query("begin");
    await client.query("set local role authenticated");
    await client.query("select set_config('request.jwt.claim.sub',$1,true)", [
      user.id,
    ]);
    let result;
    if (url.pathname.startsWith("/rest/v1/rpc/")) {
      const fn = url.pathname.split("/").at(-1)!;
      if (!["save_routine", "start_workout", "change_workout"].includes(fn))
        throw new Error("Unknown RPC");
      const keys = Object.keys(body);
      result = await client.query(
        "select public." +
          identifier(fn) +
          "(" +
          keys.map((k, i) => identifier(k) + " => $" + (i + 1)).join(",") +
          ") as value",
        Object.values(body),
      );
      await client.query("commit");
      return send(200, result.rows[0].value);
    }
    const table = url.pathname.split("/").at(-1)!;
    if (!tables.has(table)) throw new Error("Unknown table");
    const values: unknown[] = [];
    const filters: string[] = [];
    for (const [key, value] of url.searchParams) {
      if (["select", "order", "offset", "limit"].includes(key)) continue;
      if (!value.startsWith("eq.")) throw new Error("Unsupported test filter");
      values.push(value.slice(3));
      filters.push(identifier(key) + " = $" + values.length);
    }
    const where = filters.length ? " where " + filters.join(" and ") : "";
    if (req.method === "GET") {
      const order = (url.searchParams.get("order") ?? "id.asc")
        .split(",")
        .map((v) => {
          const [column, direction] = v.split(".");
          return identifier(column) + (direction === "desc" ? " desc" : " asc");
        })
        .join(",");
      values.push(
        Number(url.searchParams.get("limit") ?? 1000),
        Number(url.searchParams.get("offset") ?? 0),
      );
      result = await client.query(
        "select * from public." +
          identifier(table) +
          where +
          " order by " +
          order +
          " limit $" +
          (values.length - 1) +
          " offset $" +
          values.length,
        values,
      );
    } else if (req.method === "DELETE") {
      result = await client.query(
        "delete from public." + identifier(table) + where + " returning *",
        values,
      );
    } else if (req.method === "POST") {
      const entry = Array.isArray(body) ? body[0] : body;
      const keys = Object.keys(entry);
      result = await client.query(
        "insert into public." +
          identifier(table) +
          "(" +
          keys.map(identifier).join(",") +
          ") values(" +
          keys.map((_, i) => "$" + (i + 1)).join(",") +
          ") returning *",
        Object.values(entry),
      );
    } else throw new Error("Unsupported method");
    await client.query("commit");
    return send(200, result.rows);
  } catch (error) {
    if (client) await client.query("rollback");
    const e = error as { code?: string; message: string };
    return send(400, { code: e.code ?? "test_transport", message: e.message });
  } finally {
    client?.release();
  }
});
await new Promise<void>((resolve) => api.listen(54329, "127.0.0.1", resolve));
const testEnvironment = {
  ...process.env,
  NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54329",
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "test-only-public-key",
  NEXT_PUBLIC_SITE_URL: "http://localhost:3100",
};
const build = spawn("npm", ["run", "build"], {
  stdio: "inherit",
  env: testEnvironment,
});
const buildCode = await new Promise<number | null>((resolve) =>
  build.on("exit", resolve),
);
if (buildCode !== 0) process.exit(buildCode ?? 1);
const next = spawn(
  "node",
  ["node_modules/next/dist/bin/next", "start", "--port", "3100"],
  {
    stdio: "inherit",
    env: testEnvironment,
  },
);
let closing = false;
async function cleanup() {
  if (closing) return;
  closing = true;
  next?.kill("SIGTERM");
  api.close();
  await pool.end();
  process.exit();
}
process.on("SIGTERM", () => void cleanup());
process.on("SIGINT", () => void cleanup());
next.on("exit", () => void cleanup());
