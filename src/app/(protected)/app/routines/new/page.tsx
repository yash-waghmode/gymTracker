import { getTraining } from "@/data/training";
import { RoutineEditor } from "@/components/training/forms";
export default async function NewRoutine() {
  const { catalog } = await getTraining();
  return (
    <>
      <header className="page-heading">
        <h1>Build your routine.</h1>
      </header>
      <RoutineEditor catalog={catalog} />
    </>
  );
}
