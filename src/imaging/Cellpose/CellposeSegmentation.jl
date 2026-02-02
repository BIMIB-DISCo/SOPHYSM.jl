module CellposeSegmentation

using Colors
using PNGFiles
using JSON
using Dates
using Base.Threads

import CellposeWrapper

export start_segmentation_SOPHYSM_cellpose
export start_cellpose_job, poll_cellpose_job

# ------------------------------
# (A) Sync direct call (debug / fallback)
# ------------------------------
function start_segmentation_SOPHYSM_cellpose(input_path::String, output_path::String)
  # init + call nello stesso thread (safe in sync)
  CellposeWrapper._init_py!()
  res = CellposeWrapper.segment_image(input_path; return_flows=false)

  masks = Int.(res.masks)
  maxid = maximum(masks)
  println("[THREAD-$(Threads.threadid())] masks size=$(size(masks)) maxid=$maxid")

  cols = maxid > 0 ? distinguishable_colors(maxid) : RGB[]

  h, w = size(masks)
  out = Matrix{RGB{Float32}}(undef, h, w)

  @inbounds for i in 1:h, j in 1:w
    id = masks[i, j]
    if id == 0
      out[i, j] = RGB{Float32}(0, 0, 0)
    else
      idx = ((id - 1) % length(cols)) + 1
      c = cols[idx]
      out[i, j] = RGB{Float32}(c.r, c.g, c.b)
    end
  end

  PNGFiles.save(output_path, out)
  return output_path
end

# ------------------------------
# (B) Async stable mode: Julia worker process
# ------------------------------
const _DONE_JSON = Ref{String}("")
const _STATUS_JSON = Ref{String}("")
const _OUT_PATH = Ref{String}("")
const _RUNNING = Threads.Atomic{Bool}(false)

"""
    start_cellpose_job(input_path, output_path) -> Int

Avvia un worker Julia separato (single-thread) che esegue CellposeWrapper e salva output_path.
Ritorna 0 se avviato, -1 se già running.
"""
function start_cellpose_job(input_path::String, output_path::String)
  if _RUNNING[]
    return -1
  end
  _RUNNING[] = true

  tmpdir = mktempdir()
  _STATUS_JSON[] = joinpath(tmpdir, "status.json")
  _DONE_JSON[] = joinpath(tmpdir, "done.json")
  _OUT_PATH[] = output_path

  worker = joinpath(@__DIR__, "cellpose_worker.jl")

  # usa lo stesso Julia (julia_cmd) e lo stesso progetto attivo della GUI
  projfile = Base.active_project()
  projdir = dirname(projfile)

  cmd = `$(Base.julia_cmd()) -t 1 --project=$(projdir) $worker $input_path $output_path $(_STATUS_JSON[]) $(_DONE_JSON[])`

  # avvio non bloccante
  run(cmd; wait=false)

  return 0
end

"""
    poll_cellpose_job() -> String

Ritorna:
- "" se job ancora running
- output_path se ok
- "ERROR" se fallito
"""
function poll_cellpose_job()
  if _DONE_JSON[] == "" || !isfile(_DONE_JSON[])
    return ""
  end

  try
    obj = JSON.parsefile(_DONE_JSON[])
    ok = get(obj, "ok", false)

    _RUNNING[] = false

    if ok == true
      return String(get(obj, "output", _OUT_PATH[]))
    else
      # puoi stampare errore se vuoi
      err = get(obj, "error", "unknown error")
      println("[CELLPOSE WORKER ERROR] ", err)
      return "ERROR"
    end
  catch e
    _RUNNING[] = false
    println("[CELLPOSE POLL ERROR] ", sprint(showerror, e))
    return "ERROR"
  end
end

end # module
