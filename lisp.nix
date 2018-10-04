with import <nixpkgs/lib>;

{ a }@s: let
  inherit (builtins.unsafeGetAttrPos "a" s) file line;

  skipLines = str: let
    skipLines' = i: num:
      if num == 0 then substring i (-1) str else
      if substring i 1 str == "\n" then skipLines' (i + 1) (num - 1)
      else skipLines' (i + 1) num;
  in skipLines' 0;

  content = skipLines (builtins.readFile file) line;

  varfirst = "a-zA-Z_";
  varfollow = "${varfirst}0-9";

  skipNonVars = str: let
    match = head (builtins.match "([^${varfirst}]*).*" str);
  in substring (stringLength match) (-1) str;

  getVar = str: let
    match = builtins.match "([${varfirst}][${varfollow}]*).*" str;
  in if isNull match then null else {
    var = head match;
    rest = substring (stringLength (head match)) (-1) str;
  };

  getVars = str: let
    next = getVar (skipNonVars str); in
  if next == null then [] else
    [ next.var ] ++ getVars next.rest;
  

  contents = tail (splitString "\n" (builtins.readFile file));
  vars = filter (str: stringLength str > 0) (concatMap (splitString " ") contents);
  varsnew = filter (str: stringLength str > 0) (splitString "" content);

  v = getVars content;

in
  genAttrs v (name: {
    sym = name;
    args = [];
    __functor = self: arg: self // {
      args = self.args ++ [arg];
    };
  }) // {
    eval = let
      eval' = scope: expr: if expr ? __functor then
        if expr.sym == "def" then let
          var = { ${(elemAt expr.args 0).sym} = args: eval' (scope // var) (elemAt (elemAt expr.args 0).args 0); };
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
        else
        let args = map (eval' scope) expr.args; in
        scope.${expr.sym} args
      else expr;
    in eval' {
      plus = args: elemAt args 0 + elemAt args 1;
      minus = args: elemAt args 0 - elemAt args 1;
      times = args: elemAt args 0 * elemAt args 1;
      eq = args: elemAt args 0 == elemAt args 1;
      lt = args: elemAt args 0 < elemAt args 1;
    };

  }
