-- Omarchy 既定(default/hypr/input.lua)への上書きだけを書く。

hl.config({
  input = {
    -- Ubuntu 時代の `xset r rate 225 30` 相当
    repeat_delay = 225,
    repeat_rate = 30,

    -- ポインターの移動速度(-1.0〜1.0、既定 0)を少し上げる
    sensitivity = 0.3,

    touchpad = {
      -- スクロール方向を反転(ナチュラルスクロール)
      natural_scroll = true,
    },
  },
})

-- 3 本指の左右スワイプでワークスペース 1・2 を切り替える。
-- action = "workspace" は指に合わせて画面がスライドするので、スワイプ完了時に一瞬で切り替える dispatch にする。
-- 指を左へ = 右隣(2)へ、右へ = 左隣(1)へ(Mac と同じ向き)
hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ workspace = "2" })) end })
hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ workspace = "1" })) end })
