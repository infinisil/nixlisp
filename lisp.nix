with import <nixpkgs/lib>;

{ a }@set: let

  skipLines = str: let
    skipLines' = i: num:
      if num == 0 then substring i (-1) str else
      if substring i 1 str == "\n" then skipLines' (i + 1) (num - 1)
      else skipLines' (i + 1) num;
  in skipLines' 0;

  vars = map (x: x.sym) (import ./extract-vars.nix {
    content = let inherit (builtins.unsafeGetAttrPos "a" set) file line;
      in skipLines (builtins.readFile file) line;
  });

  /*
  For each variable, generate an attribute set containing its name
  and make it callable with __functor, such that `(a b c)` works, resulting in
  something like

    {
      sym = "a"
      args = [
        { sym = "b"; }
        { sym = "c"; }
      ];
    }

  */
  varAttrs = genAttrs vars (name: {
    sym = name;
    args = [];
    __functor = self: arg: self // {
      args = self.args ++ [arg];
    };
  });

  liftFun = f: args: index:
    if index >= length args then f
    else liftFun (f (elemAt args index)) args (index + 1);

in
  varAttrs // {
    eval = let
      eval' = scope: expr: if expr ? __functor then
        if expr.sym == "def" then let
          varname = (elemAt expr.args 0).sym;
          value = eval' (scope // var) (elemAt (elemAt expr.args 0).args 0);
          var = { ${varname} = args: value; };
          in eval' (scope // var) (elemAt expr.args 1)
        else if expr.sym == "defun" then let
          fun = {
            ${(elemAt expr.args 0).sym} = args: let
              localvars = {
                ${(elemAt expr.args 1).sym} = _: head args;
              } // listToAttrs (zipListsWith (s: v: { name = s.sym; value = args: v; }) (elemAt expr.args 1).args (tail args));
            in eval' (scope // fun // localvars) (elemAt expr.args 2);
          };
          in eval' (scope // fun) (elemAt expr.args 3)
        else if expr.sym == "iff" then let
          cond = elemAt expr.args 0;
          condval = eval' scope cond;
          ifthen = elemAt expr.args 1;
          ifelse = elemAt expr.args 2;
          in eval' scope (if condval then ifthen else ifelse)
        else if expr.sym == "lift" then let
          args = map (eval' scope) expr.args;
          in liftFun (elemAt expr.args 0) args 1
        else
        let args = map (eval' scope) expr.args; in
        scope.${expr.sym} args
      else expr;
      builtinScope = {
        plus = args: elemAt args 0 + elemAt args 1;
        minus = args: elemAt args 0 - elemAt args 1;
        times = args: elemAt args 0 * elemAt args 1;
        eq = args: elemAt args 0 == elemAt args 1;
        lt = args: elemAt args 0 < elemAt args 1;
      };
    in eval' builtinScope;

  }
