---------------------------------------------------------------------------------------
-- Module to fiddle with the Windows Registry. (Modified For Cheat Engine By dr NHA)
-- Version 0.1, [copyright (c) 2023 - dr NHA & Thijs Schreijer](http://www.thijsschreijer.nl)

if 1 then;--Registry For Cheat Engine
-- Function Name Register (Incase User Hasnt Already Got NHA_CE)
FNR=function(Name);registerLuaFunctionHighlight(Name);end;FNR("FNR");

--Main Variable
Registry = {_L={}};
FNR("Registry");
FNR("Registry._L");

if 1 then;--"local functions" These Were Originally Local But Why Not Make Them Public For No Real Reason :)
--- execute a shell command and return the output.

Registry._L.ExecuteEx=function(cmd)
local outcontent, errcontent, fh

--Local As Otherwise Its Easier To Tamper
local CF_=function();
local D=os.tmpname()
--If Tempname Has No Path Append Tempname To The Temp Directory Path
if string.find(D,"\\")<0 then;
D = os.getenv('TEMP')..D;
end;
os.remove(D);
return D;
end;

local CR_=function(Input,Dat);
 fh = io.open(Input)
  if fh then
    Dat = fh:read("*a"):match( "^%s*(.-)%s*$" )
    fh:close()
  end
  os.remove(Input)
  return Dat;
end;


local outfile,errfile =CF_(),CF_();

cmd = cmd .. [[ >"]]..outfile..[[" 2>"]]..errfile..[["]]

local success, retcode = os.execute(cmd)

outcontent =CR_(outfile,outcontent)
errcontent =CR_(errfile,errcontent)

  return success, retcode, (outcontent or ""), (errcontent or "")
end

-- Splits a string using a pattern
Registry._L.Split = function(str, pat)
  local t = {}
  local fpat = "(.-)" .. pat
  local last_end = 1
  local s, e, cap = str:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= "" then
      table.insert(t,cap)
    end
    last_end = e+1
    s, e, cap = str:find(fpat, last_end)
  end
  if last_end <= #str then
    cap = str:sub(last_end)
    table.insert(t, cap)
  end
  return t
end

-- wrap string in double quotes
Registry._L.dqwrap = function(str)
  assert(type(str)=="string", "Expected string, got "..type(str))
  return '"'..str..'"'
end

--Parse Output To Registry Info Table
function Registry._L.ParseQuery(output, i)
  assert(type(output) == "string" or type(output) == "table", "Expected string or table, got "..type(output))
  local lines=nil;
  if type(output) == "string" then
    lines = Registry._L.Split(output, "\n")
  else
    lines = output
  end
  local i = i or 1
  local result = { values = {}, keys = {} }
  while i <= #lines do
    if lines[i] ~= "" then
      if result.key then
        -- key already set, so this is content
        if lines[i]:sub(1,1) == " " then
          -- starts with whitespace, so it is a value
          local n, t, v = lines[i]:match("^%s%s%s%s(.+)%s%s%s%s(REG_.+)%s%(%d%d?%)%s%s%s%s(.*)$")
          result.values[n] = { ["type"] = t, value = v, name = n}
        elseif lines[i]:find(result.key,1,true) == 1 then
          -- the line starts with the same sequence as our key, so it is a sub-key
          local skey
          local name = lines[i]:sub(#result.key + 2, -1)
          skey, i = Registry._L.ParseQuery(lines, i)
          result.keys[name] = skey
        else
          -- something else, so a key on a higher level
      return result, i-1
        end
      else
        -- key not set, so this is the key
        result.key = lines[i]
      end
    else
      if result.key then
        -- blank line while key already set, so we're done with the values
        while lines[i] == "" and i <= #lines do i = i + 1 end
        if lines[i] then
          if lines[i]:find(result.key,1,true) ~= 1 then
            -- the next key in the list is not a sub key, so we're done
            return result, i
          else
            i = i - 1
          end
        end
      end
    end
    i = i + 1
  end
  if result.key then
    return result, i
  else
    return nil,-1
  end
end

end;
--[[*******************************************************************]]

if 1 then;--Functions
--Get A Keys Info Or Nil If None
Registry.GetKey=function(key, recursive)
  assert(type(key)=="string", "Expected string, got "..type(key))
  local options = " /z"
  if recursive then options = options.." /s" end
  local ok, ec, out, err = Registry._L.ExecuteEx("reg.exe query "..Registry._L.dqwrap(key)..options)
  if not ok then
  print("Key :"+key+" Was Invalid!");
    return nil, (Registry._L.Split(err,"\n"))[1]  -- return only first line of error
  else
    local result,Count = Registry._L.ParseQuery(out)
    if not recursive then
      -- when not recursive, then remove empty tables
      for _, v in pairs(result.keys) do
        v.keys = nil
        v.values = nil
      end
    end
    return result,Count
  end
end
FNR("Registry.GetKey");

--Debugging Function
Registry.PrintKeyDebugInfo=function(key,recursive);
local DB,DBT=Registry.GetKey(key,recursive);
print("Registry Key: "..DB.key);
print("Output Lines Count: "..DBT);
local I,OUT=0,"";
local Name,Value,Type=nil,nil,nil;
for Name in pairs(DB.values) do;
Type=DB.values[Name]["type"];
Value=DB.values[Name].value;
OUT=OUT..Name.."("..Type.."): "..Value.."\n"
I=I+1;
end;
print(OUT);
print("Displayed Count: "..I);
end;
FNR("Registry.PrintKeyDebugInfo");

--Create A Key
Registry.CreateKey=function(key)
  local ok, ec, out, err = Registry._L.ExecuteEx([[reg.exe add ]]..Registry._L.dqwrap(key)..[[ /f]])
  if not ok then
    return nil, (Registry._L.Split(err,"\n"))[1]  -- return only first line of error
  else
    return true
  end
end
FNR("Registry.CreateKey");

--Delete A Key
Registry.DeleteKey=function(key)
  local ok, ec, out, err = Registry._L.ExecuteEx([[reg.exe delete ]]..Registry._L.dqwrap(key)..[[ /f]])
  if not ok then
    if not Registry.GetKey(key) then return true end -- it didn't exist in the first place
    return nil, (Registry._L.Split(err,"\n"))[1]  -- return only first line of error
  else
    return true
  end
end
FNR("Registry.DeleteKey");

--Write A Value To A Key
Registry.WriteValue=function(key, name, vtype, value)
  local command
  if name == "(Default)" or name == nil then
    command = ("reg.exe add %s /ve /t %s /d %s /f"):format(Registry._L.dqwrap(key), vtype, Registry._L.dqwrap(value))
  else
    command = ("reg.exe add %s /v %s /t %s /d %s /f"):format(Registry._L.dqwrap(key),Registry._L.dqwrap(name), vtype, Registry._L.dqwrap(value))
  end
  local ok, ec, out, err = Registry._L.ExecuteEx(command)
  if not ok then
    return nil, (Registry._L.Split(err,"\n"))[1]  -- return only first line of error
  else
    return true
  end
end
FNR("Registry.WriteValue");

--Get A Value From A Key
Registry.GetValue=function(key, name)
  local keyt = (type(key)=="string") and Registry.GetKey(key) or key;
  if keyt then
    if keyt.values[name] then
      -- it exists, return value and type
      return keyt.values[name].value, keyt.values[name].type
    end
  end
  return nil
end
FNR("Registry.GetValue");
 
--Delete A Value From A Key
Registry.DeleteValue=function(key, name)
  local command
  if name == "(Default)" or name == nil then
    command = ("reg.exe delete %s /ve /f"):format(Registry._L.dqwrap(key))
  else
    command = ("reg.exe delete %s /v %s /f"):format(Registry._L.dqwrap(key),Registry._L.dqwrap(name))
  end
  local ok, ec, out, err = Registry._L.ExecuteEx(command)
  if not ok then
    if not Registry.GetValue(key, name) then return true end -- it didn't exist in the first place
    return nil, (Registry._L.Split(err,"\n"))[1]  -- return only first line of error
  else
    return true
  end
end
FNR("Registry.DeleteValue");

end;
--[[*******************************************************************]]

end;
--[[*******************************************************************]]
