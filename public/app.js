document.getElementById("pulse")?.addEventListener("click",()=>{
  document.getElementById("out").textContent = JSON.stringify({
    system:"MUBAKA_PUBLIC_REPO_SURFACE",
    status:"PASS",
    state:"PUBLIC_REPO_SURFACE_ACTIVE",
    utc:new Date().toISOString()
  },null,2);
});
