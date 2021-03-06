(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Linker;	(* pjm *)

IMPORT SYSTEM, Linker0, Linker1, Streams, Files, Commands, Modules := Linker0;

PROCEDURE GetOptions(r: Streams.Reader; VAR opts: ARRAY OF CHAR);
VAR i: LONGINT; ch: CHAR;
BEGIN
	i := 0;
	WHILE opts[i] # 0X DO INC(i) END;
	r.SkipWhitespace;
	ch := r.Peek();
	WHILE (ch = "\") DO
		r.Char(ch); (* skip \ *)
		r.Char(ch);
		WHILE (ch > " ") DO
			opts[i] := ch;  INC(i); r.Char(ch)
		END;
		opts[i] := " "; INC(i);
		r.SkipWhitespace;
		ch := r.Peek()
	END;
	opts[i] := 0X
END GetOptions;

	PROCEDURE ParseOptions(VAR options, prefix, extension: ARRAY OF CHAR);
	VAR  i: LONGINT;  ch: CHAR;

		PROCEDURE SubString(VAR str: ARRAY OF CHAR);
		VAR ch: CHAR;  j: LONGINT;
		BEGIN
			ch := options[i]; INC(i); j := 0;
			WHILE (ch # 0X) & (ch # " ") DO
				str[j] := ch; ch := options[i]; INC(j); INC(i)
			END;
			str[j] := 0X
		END SubString;

	BEGIN
		REPEAT
			ch := options[i]; INC(i);
			IF ch = "." THEN DEC(i); SubString(extension)
			ELSIF ch = "P" THEN SubString(prefix)
			END;
		UNTIL ch = 0X;
	END ParseOptions;

PROCEDURE Link*(context : Commands.Context);	(** [\.Extension] [\PPath] outFile baseAdr [loadAdr] { module } *)
VAR
	m: Modules.Module;  res: LONGINT; base, load: LONGINT;
	out,prefix,suffix,options,filename: Files.FileName;
	msg: ARRAY 256 OF CHAR;
	r: Files.Writer; f: Files.File;
BEGIN
	options := ""; GetOptions(context.arg, options); ParseOptions(options,prefix,suffix);

	IF context.arg.GetString(out) THEN
		IF context.arg.GetInteger(base,TRUE) THEN

			(*  If there is a load address store it, else the load address is the same as the base address. *)
			(*?? Sven, how can I do optional parsing? If I leave out load adr then it does not scan strings any more ..   *)
			IF ~context.arg.GetInteger(load,TRUE) THEN base := load END;

			Linker0.Open(prefix, suffix, base, NIL); (* NIL -> context.arg.out means log to console, otherwise a log file is generated *)

			res := Linker1.Ok;

			context.out.String("Linking "); context.out.String(out); context.out.Ln;
			context.out.String("Base="); context.out.Hex(base,1); context.out.String(", load="); context.out.Hex(load,1);
			context.out.Ln; context.out.String("Modules:"); context.out.Update;

			(* While everything is okay load the different modules {module} *)
			WHILE context.arg.GetString(filename) DO
				context.out.String(filename); context.out.String(" "); context.out.Update;
				m := Modules.ThisModule(filename, res, msg);
			END;
			context.out.Ln;

			f := Files.New(out);
			IF f = NIL THEN context.error.String("Could not open file :"); context.error.String(out); context.error.Ln; END;
			NEW(r,f,0);
			Linker0.Close(r, load, res, msg, context.out);
			r.Update;  Files.Register(f);  f.Update;

		END
	END
END Link;

END Linker.

(*
20.05.98	pjm	Started
*)

SystemTools.Free Linker0 Linker1 Linker  ~
