export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

type Relationship = {
  foreignKeyName: string;
  columns: string[];
  isOneToOne: boolean;
  referencedRelation: string;
  referencedColumns: string[];
};

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          display_name: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          display_name?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          display_name?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      exercises: {
        Row: {
          id: string;
          owner_id: string | null;
          name: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          owner_id?: string | null;
          name: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          owner_id?: string | null;
          name?: string;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "exercises_owner_id_fkey";
            columns: ["owner_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      routines: {
        Row: {
          id: string;
          owner_id: string;
          name: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          owner_id: string;
          name: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          owner_id?: string;
          name?: string;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "routines_owner_id_fkey";
            columns: ["owner_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      routine_exercises: {
        Row: {
          id: string;
          routine_id: string;
          owner_id: string;
          exercise_id: string;
          position: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          routine_id: string;
          owner_id: string;
          exercise_id: string;
          position: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          routine_id?: string;
          owner_id?: string;
          exercise_id?: string;
          position?: number;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "routine_exercises_exercise_id_fkey";
            columns: ["exercise_id"];
            isOneToOne: false;
            referencedRelation: "exercises";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "routine_exercises_routine_owner_fk";
            columns: ["routine_id", "owner_id"];
            isOneToOne: false;
            referencedRelation: "routines";
            referencedColumns: ["id", "owner_id"];
          },
        ];
      };
      workout_sessions: {
        Row: {
          id: string;
          created_by: string;
          title: string | null;
          status: string;
          started_at: string | null;
          ended_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          created_by: string;
          title?: string | null;
          status?: string;
          started_at?: string | null;
          ended_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          created_by?: string;
          title?: string | null;
          status?: string;
          started_at?: string | null;
          ended_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "workout_sessions_created_by_fkey";
            columns: ["created_by"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      session_participants: {
        Row: {
          session_id: string;
          user_id: string;
          joined_at: string;
          left_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          session_id: string;
          user_id: string;
          joined_at?: string;
          left_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          session_id?: string;
          user_id?: string;
          joined_at?: string;
          left_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "session_participants_session_id_fkey";
            columns: ["session_id"];
            isOneToOne: false;
            referencedRelation: "workout_sessions";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "session_participants_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      workouts: {
        Row: {
          id: string;
          session_id: string;
          owner_id: string;
          routine_id: string | null;
          started_at: string;
          completed_at: string | null;
          notes: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          session_id: string;
          owner_id: string;
          routine_id?: string | null;
          started_at?: string;
          completed_at?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          session_id?: string;
          owner_id?: string;
          routine_id?: string | null;
          started_at?: string;
          completed_at?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "workouts_routine_id_fkey";
            columns: ["routine_id"];
            isOneToOne: false;
            referencedRelation: "routines";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "workouts_session_owner_fk";
            columns: ["session_id", "owner_id"];
            isOneToOne: true;
            referencedRelation: "session_participants";
            referencedColumns: ["session_id", "user_id"];
          },
        ];
      };
      workout_exercises: {
        Row: {
          id: string;
          workout_id: string;
          owner_id: string;
          exercise_id: string;
          position: number;
          notes: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          workout_id: string;
          owner_id: string;
          exercise_id: string;
          position: number;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          workout_id?: string;
          owner_id?: string;
          exercise_id?: string;
          position?: number;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "workout_exercises_exercise_id_fkey";
            columns: ["exercise_id"];
            isOneToOne: false;
            referencedRelation: "exercises";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "workout_exercises_workout_owner_fk";
            columns: ["workout_id", "owner_id"];
            isOneToOne: false;
            referencedRelation: "workouts";
            referencedColumns: ["id", "owner_id"];
          },
        ];
      };
      workout_sets: {
        Row: {
          id: string;
          workout_exercise_id: string;
          owner_id: string;
          position: number;
          reps: number;
          weight_kg: number | null;
          performed_at: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          workout_exercise_id: string;
          owner_id: string;
          position: number;
          reps: number;
          weight_kg?: number | null;
          performed_at?: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          workout_exercise_id?: string;
          owner_id?: string;
          position?: number;
          reps?: number;
          weight_kg?: number | null;
          performed_at?: string;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "workout_sets_exercise_owner_fk";
            columns: ["workout_exercise_id", "owner_id"];
            isOneToOne: false;
            referencedRelation: "workout_exercises";
            referencedColumns: ["id", "owner_id"];
          },
        ];
      };
    };
    Views: { [_ in never]: never };
    Functions: { [_ in never]: never };
    Enums: { [_ in never]: never };
    CompositeTypes: { [_ in never]: never };
  };
};

type PublicTables = Database["public"]["Tables"];

export type TableName = keyof PublicTables;
export type Tables<Name extends TableName> = PublicTables[Name]["Row"];
export type TablesInsert<Name extends TableName> = PublicTables[Name]["Insert"];
export type TablesUpdate<Name extends TableName> = PublicTables[Name]["Update"];

export type DatabaseRelationship = Relationship;
