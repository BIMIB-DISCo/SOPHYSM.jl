module CellposeSegmentation

using Colors
using PNGFiles
import CellposeWrapper
using Base.Threads

export start_segmentation_SOPHYSM_cellpose

"""
    start_segmentation_SOPHYSM_cellpose(input_path, output_path; cache_models=true, max_cached_models=2) -> String

Esegue Cellpose tramite CellposeWrapper (che gestisce init lazy + lock Python interno),
converte la mask in una mappa RGB e salva un PNG.
"""
function start_segmentation_SOPHYSM_cellpose(input_path::String, output_path::String;
  cache_models::Bool=true,
  max_cached_models::Int=2
)
  # Wrapper gestisce init + lock python internamente: NESSUN lock esterno qui.
  res = CellposeWrapper.segment_image(
    input_path;
    return_flows=false,
    cache_models=cache_models,
    max_cached_models=max_cached_models
  )

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
      # wrap-around per sicurezza
      idx = ((id - 1) % length(cols)) + 1
      c = cols[idx]  # RGB{Float64}
      out[i, j] = RGB{Float32}(c.r, c.g, c.b)
    end
  end

  mkpath(dirname(output_path))
  PNGFiles.save(output_path, out)

  return output_path
end

end # module