# cellpose_worker.jl
using JSON
using Dates
using CellposeWrapper
using PNGFiles
using Colors

function write_json_atomic(path::String, obj)
  tmp = path * ".tmp"
  open(tmp, "w") do io
    JSON.print(io, obj)
  end
  mv(tmp, path; force=true)
end

function main()
  if length(ARGS) < 4
    println("Usage: julia cellpose_worker.jl <input> <output_png> <status_json> <done_json>")
    exit(2)
  end

  input_path = ARGS[1]
  output_path = ARGS[2]
  status_path = ARGS[3]
  done_path = ARGS[4]

  try
    write_json_atomic(status_path, Dict(
      "state" => "starting",
      "time" => string(now()),
      "msg" => "Initializing Cellpose/Python..."
    ))

    # init + run
    CellposeWrapper._init_py!()

    write_json_atomic(status_path, Dict(
      "state" => "running",
      "time" => string(now()),
      "msg" => "Running segmentation..."
    ))

    res = CellposeWrapper.segment_image(input_path; return_flows=false)

    masks = Int.(res.masks)
    maxid = maximum(masks)

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

    write_json_atomic(done_path, Dict(
      "ok" => true,
      "output" => output_path,
      "time" => string(now())
    ))

    write_json_atomic(status_path, Dict(
      "state" => "done",
      "time" => string(now()),
      "msg" => "Completed."
    ))

    exit(0)

  catch e
    write_json_atomic(done_path, Dict(
      "ok" => false,
      "error" => sprint(showerror, e),
      "time" => string(now())
    ))

    write_json_atomic(status_path, Dict(
      "state" => "error",
      "time" => string(now()),
      "msg" => sprint(showerror, e)
    ))

    exit(1)
  end
end

main()
