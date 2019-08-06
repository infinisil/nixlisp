# Extracts all variable names from a string
{ content # The string to extract variables from
, varFirst ? "a-zA-Z_" # Regex for first variable character
, varFollow ? varFirst + "0-9" # Regex for variable characters after initial one
}: let
  inherit (builtins) head substring stringLength match;

  countLines = str:
    let matched = match "([^\n]*\n).*" str;
    in if matched == null then 0
    else 1 + countLines (substring (stringLength (head matched)) (-1) str);

  # Drops characters from a string until a varFirst one is found
  skipNonVars = { str, line }:
    let matched = head (match "([^${varFirst}]*).*" str);
        lineDiff = countLines matched;
    in {
      str = substring (stringLength matched) (-1) str;
      line = line + lineDiff;
    };

  # Takes a variable from the start of a string and returns it along with the
  # rest string, or null if there's no variable at the start
  getVar = { str, line }: let
    matched = match "([${varFirst}][${varFollow}]*).*" str;
  in if isNull matched then null else {
    var = {
      sym = head matched;
      inherit line;
    };
    str = substring (stringLength (head matched)) (-1) str;
    inherit line;
  };

  # Extracts all variables from a string
  getVars = { str, line }:
    let next = getVar (skipNonVars { inherit str line; });
    in if next == null then [] else
      [ next.var ] ++ getVars { str = next.str; inherit (next) line; };
  
in getVars { str = content; line = 1; }
