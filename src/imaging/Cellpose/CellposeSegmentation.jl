module CellposeSegmentation

using Colors
using PNGFiles
import CellposeWrapper

export start_segmentation_SOPHYSM_cellpose

function start_segmentation_SOPHYSM_cellpose(input_path::String, output_path::String)
  # Prendiamo solo masks (più stabile e leggero)
  res = CellposeWrapper.segment_image(input_path; return_flows=false)

  masks = Int.(res.masks)
  maxid = maximum(masks)
  println("masks size = $(size(masks)) maxid = $maxid")

  # Colori distinguibili (RGB{Float64})
  cols = maxid > 0 ? distinguishable_colors(maxid) : RGB[]

  # Output tipizzato: PNGFiles lo salva senza problemi
  h, w = size(masks)
  out = Matrix{RGB{Float32}}(undef, h, w)

  @inbounds for i in 1:h, j in 1:w
    id = masks[i, j]
    if id == 0
      out[i, j] = RGB{Float32}(0, 0, 0)
    else
      c = cols[id]  # RGB{Float64}
      out[i, j] = RGB{Float32}(c.r, c.g, c.b)
    end
  end

  PNGFiles.save(output_path, out)
  return output_path
end

end
