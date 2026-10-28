import QtQuick

// Dual-mode audio visualizer around the scalloped cover:
// - "bars": thick rounded radial capsule rays + wavy inner ring (Image 2)
// - "wave": morphing liquid aura blob + scalloped collar ring (Image 1)
Item {
    id: root
    property var bars: visualizer ? visualizer.bars : []
    property bool active: visualizer ? visualizer.active : false
    property bool playing: false
    property string style: session ? session.visualizerStyle : "bars" // "bars" | "wave"
    property color accentColor: Theme.accent
    property real coverRadius: width * 0.30
    property int scallops: 24
    property real scallopDepth: 0.038
    readonly property int numRays: 72

    property var _smooth: []
    property real _time: 0
    property real _bass: 0
    property real _mid: 0
    property real _high: 0

    function sampleBin(arr, idx) {
        if (!arr || arr.length === 0)
            return 0
        const clamped = Math.max(0, Math.min(arr.length - 1, idx))
        const i0 = Math.floor(clamped)
        const i1 = Math.min(arr.length - 1, i0 + 1)
        const frac = clamped - i0
        return (arr[i0] || 0) * (1 - frac) + (arr[i1] || 0) * frac
    }

    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
    }

    function mixColor(c1, c2, t, a) {
        const r = Math.round((c1.r * (1 - t) + c2.r * t) * 255)
        const g = Math.round((c1.g * (1 - t) + c2.g * t) * 255)
        const b = Math.round((c1.b * (1 - t) + c2.b * t) * 255)
        return "rgba(" + r + "," + g + "," + b + "," + a + ")"
    }

    FrameAnimation {
        id: anim
        running: root.visible && (root.active || root.playing)
        onTriggered: {
            const dt = Math.min(0.05, frameTime)
            root._time += dt

            const N = root.numRays
            if (root._smooth.length !== N) {
                const init = new Array(N)
                for (let i = 0; i < N; i++) init[i] = 0.25
                root._smooth = init
            }

            const raw = root.bars || []
            const rawLen = raw.length
            let maxSignal = 0
            for (let i = 0; i < rawLen; i++) {
                if ((raw[i] || 0) > maxSignal) maxSignal = raw[i]
            }
            const hasCava = root.active && maxSignal > 0.008
            const t = root._time

            // Compute band energies (bass, mid, high)
            let bE = 0, mE = 0, hE = 0
            if (hasCava) {
                for (let i = 0; i < 12; i++) bE += raw[i] || 0
                for (let i = 12; i < 36; i++) mE += raw[i] || 0
                for (let i = 36; i < rawLen; i++) hE += raw[i] || 0
                bE /= 12
                mE /= 24
                hE /= Math.max(1, rawLen - 36)
            } else if (root.playing) {
                bE = 0.45 + 0.42 * Math.pow(0.5 + 0.5 * Math.sin(t * 5.8), 2.2)
                mE = 0.35 + 0.35 * (0.5 + 0.5 * Math.sin(t * 4.1 + 1.1))
                hE = 0.25 + 0.25 * (0.5 + 0.5 * Math.cos(t * 7.3))
            }

            root._bass += (bE - root._bass) * Math.min(1.0, dt * 14.0)
            root._mid  += (mE - root._mid)  * Math.min(1.0, dt * 12.0)
            root._high += (hE - root._high) * Math.min(1.0, dt * 12.0)

            const cur = root._smooth
            const attack = Math.min(1.0, dt * 22.0)
            const release = Math.min(1.0, dt * 9.0)

            for (let i = 0; i < N; i++) {
                const a = (i / N) * Math.PI * 2
                // Symmetric 8-lobe crown contour + audio spectrum modulation (like Image 2)
                const crownWave = 0.5 + 0.5 * Math.cos(8 * a + Math.sin(t * 0.9) * 0.4)
                const subWave = 0.5 + 0.5 * Math.sin(4 * a - t * 1.4)

                let val = 0.18 + 0.14 * crownWave
                if (hasCava) {
                    const halfIdx = i < (N / 2) ? i : (N - 1 - i)
                    const binPos = (halfIdx / (N / 2)) * (rawLen - 1)
                    const v = root.sampleBin(raw, binPos)
                    val = 0.22 + 0.22 * crownWave + v * (0.55 + 0.35 * subWave) + root._bass * 0.20
                } else if (root.playing) {
                    const pulse = 0.5 + 0.5 * Math.sin(8 * a - t * 3.2) * Math.cos(3 * a + t * 2.1)
                    val = 0.26 + 0.28 * crownWave * (0.65 + 0.55 * root._bass) + 0.28 * pulse * root._mid + 0.12 * subWave
                }

                val = Math.min(1.0, Math.max(0.12, val))
                const k = val > cur[i] ? attack : release
                cur[i] = cur[i] + (val - cur[i]) * k
            }

            canvas.requestPaint()
        }
    }

    onStyleChanged: canvas.requestPaint()
    onAccentColorChanged: canvas.requestPaint()
    onCoverRadiusChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const cx = width / 2
            const cy = height / 2
            const rCover = root.coverRadius
            if (rCover <= 0)
                return

            const N_scal = root.scallops
            const sDepth = root.scallopDepth
            const rBase = rCover * (1 - sDepth)
            const sAmp = rCover * sDepth
            const maxOuter = Math.min(cx, cy) - 4
            const maxSpan = Math.max(18, maxOuter - rCover)
            const t = root._time
            const acc = root.accentColor
            const white = Qt.rgba(1, 1, 1, 1)

            if (root.style === "wave") {
                // ============================================================
                // MODE 1: LIQUID MORPHING WAVE AURA (Image 1 - HIM screenshot)
                // ============================================================
                const steps = 240
                const bBoost = root._bass * 0.38 + (root.playing ? 0.12 : 0.0)
                const mBoost = root._mid * 0.28
                const blobBase = rCover + maxSpan * (0.48 + bBoost * 0.32)

                function blobRadius(a) {
                    const w1 = Math.cos(7 * a + t * 1.35) * (0.38 + bBoost * 0.45)
                    const w2 = Math.sin(5 * a - t * 1.80) * (0.28 + mBoost * 0.40)
                    const w3 = Math.cos(3 * a + t * 0.95) * 0.18
                    const w4 = Math.sin(11 * a + t * 2.4) * (0.08 + root._high * 0.18)
                    return blobBase + maxSpan * 0.28 * (w1 + w2 + w3 + w4)
                }

                // 1. Outer soft shadow / glow behind the liquid blob
                ctx.save()
                const outerGlow = ctx.createRadialGradient(cx, cy, rCover * 0.9, cx, cy, maxOuter)
                outerGlow.addColorStop(0.0, "rgba(0, 0, 0, 0.0)")
                outerGlow.addColorStop(0.55, "rgba(0, 0, 0, 0.22)")
                outerGlow.addColorStop(1.0, "rgba(0, 0, 0, 0.0)")
                ctx.fillStyle = outerGlow
                ctx.beginPath()
                ctx.arc(cx, cy, maxOuter, 0, Math.PI * 2)
                ctx.fill()
                ctx.restore()

                // 2. Main 3D pearlescent / translucent liquid wave body
                ctx.save()
                const blobGrad = ctx.createRadialGradient(cx, cy, rCover * 0.92, cx, cy, blobBase + maxSpan * 0.36)
                blobGrad.addColorStop(0.0,  "rgba(55, 60, 68, 0.65)")
                blobGrad.addColorStop(0.45, root.mixColor(acc, white, 0.65, 0.46))
                blobGrad.addColorStop(0.82, root.mixColor(acc, white, 0.82, 0.72))
                blobGrad.addColorStop(1.0,  "rgba(255, 255, 255, 0.90)")

                ctx.fillStyle = blobGrad
                ctx.beginPath()
                for (let i = 0; i <= steps; i++) {
                    const a = (i / steps) * Math.PI * 2
                    const r = blobRadius(a)
                    const x = cx + Math.cos(a) * r
                    const y = cy + Math.sin(a) * r
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()
                ctx.fill()

                // Luminous rim stroke along the outer edge of the wave blob
                ctx.lineWidth = 2.2
                ctx.strokeStyle = "rgba(255, 255, 255, 0.55)"
                ctx.stroke()
                ctx.restore()

                // 3. Secondary inner harmonic wave layer for depth
                ctx.save()
                ctx.fillStyle = "rgba(30, 33, 40, 0.26)"
                ctx.beginPath()
                for (let i = 0; i <= steps; i++) {
                    const a = (i / steps) * Math.PI * 2
                    const r = rCover + maxSpan * 0.22 + maxSpan * 0.14 * (
                        Math.sin(7 * a - t * 1.5) * 0.6 + Math.cos(6 * a + t * 1.1) * 0.4
                    )
                    const x = cx + Math.cos(a) * r
                    const y = cy + Math.sin(a) * r
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()
                ctx.fill()
                ctx.restore()

                // 4. Scalloped dark collar ring + bright inner rim around the cover
                ctx.save()
                ctx.fillStyle = "rgba(42, 46, 54, 0.78)"
                ctx.beginPath()
                for (let i = 0; i <= 360; i++) {
                    const a = (i / 360) * Math.PI * 2
                    const r = (rBase + 9) + (sAmp * 1.15) * Math.cos(N_scal * a)
                    const x = cx + Math.cos(a) * r
                    const y = cy + Math.sin(a) * r
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()
                ctx.fill()

                ctx.lineWidth = 2.0
                ctx.strokeStyle = "rgba(255, 255, 255, 0.35)"
                ctx.beginPath()
                for (let i = 0; i <= 360; i++) {
                    const a = (i / 360) * Math.PI * 2
                    const r = (rBase + 2) + sAmp * Math.cos(N_scal * a)
                    const x = cx + Math.cos(a) * r
                    const y = cy + Math.sin(a) * r
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()
                ctx.stroke()
                ctx.restore()

            } else {
                // ============================================================
                // MODE 2: THICK ROUNDED RADIAL PILL BARS (Image 2 - Panchiko)
                // ============================================================
                const N = root.numRays
                const vals = root._smooth

                // 1. Translucent accent scalloped aura behind the bars
                ctx.save()
                ctx.fillStyle = root.mixColor(acc, white, 0.15, 0.58)
                ctx.beginPath()
                for (let i = 0; i <= 360; i++) {
                    const a = (i / 360) * Math.PI * 2
                    const r = (rBase + 13) + (sAmp * 1.1) * Math.cos(N_scal * a)
                    const x = cx + Math.cos(a) * r
                    const y = cy + Math.sin(a) * r
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()
                ctx.fill()
                ctx.restore()

                // 2. Wavy inner border ring hugging the scalloped cover
                ctx.save()
                ctx.lineWidth = 2.6
                ctx.strokeStyle = root.mixColor(acc, white, 0.55, 0.92)
                ctx.beginPath()
                for (let i = 0; i <= 360; i++) {
                    const a = (i / 360) * Math.PI * 2
                    const r = (rBase + 5) + (sAmp * 1.05) * Math.cos(N_scal * a)
                    const x = cx + Math.cos(a) * r
                    const y = cy + Math.sin(a) * r
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()
                ctx.stroke()
                ctx.restore()

                // 3. 72 thick rounded radial pill bars radiating outward
                ctx.save()
                ctx.lineCap = "round"
                const barThickness = Math.max(4.2, Math.min(6.8, (2 * Math.PI * rCover / N) * 0.46))
                ctx.lineWidth = barThickness

                for (let i = 0; i < N; i++) {
                    const a = (i / N) * Math.PI * 2
                    const v = vals.length === N ? vals[i] : 0.28
                    const scalOffset = sAmp * 0.55 * Math.cos(N_scal * a)
                    const rStart = rBase + 10 + scalOffset
                    const barLen = Math.max(10, v * (maxSpan - 12))
                    const cosA = Math.cos(a)
                    const sinA = Math.sin(a)

                    // Subtle outer glow on each pill bar
                    ctx.strokeStyle = root.mixColor(acc, white, 0.25, 0.32)
                    ctx.lineWidth = barThickness + 3.0
                    ctx.beginPath()
                    ctx.moveTo(cx + cosA * rStart, cy + sinA * rStart)
                    ctx.lineTo(cx + cosA * (rStart + barLen), cy + sinA * (rStart + barLen))
                    ctx.stroke()

                    // Crisp bright pill bar
                    ctx.strokeStyle = root.mixColor(acc, white, 0.42, 0.92)
                    ctx.lineWidth = barThickness
                    ctx.beginPath()
                    ctx.moveTo(cx + cosA * rStart, cy + sinA * rStart)
                    ctx.lineTo(cx + cosA * (rStart + barLen), cy + sinA * (rStart + barLen))
                    ctx.stroke()
                }
                ctx.restore()
            }
        }
    }
}
