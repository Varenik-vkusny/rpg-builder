# Достаёт из JSON на stdin: session_id, file_path, command — по строке на каждое.
read_hook_input() {
  if command -v node >/dev/null 2>&1; then
    node -e '
let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
  let o={};try{o=JSON.parse(d)}catch(e){}
  const sid=(o.session_id||"shared").replace(/[^A-Za-z0-9_-]/g,"").slice(0,64)||"shared";
  const ti=o.tool_input||{};
  console.log(sid);
  console.log(ti.file_path||"");
  console.log((ti.command||"").replace(/[\r\n]+/g," ").slice(0,2000));
})' 2>/dev/null
  else
    echo shared; echo ""; echo ""
  fi
}
