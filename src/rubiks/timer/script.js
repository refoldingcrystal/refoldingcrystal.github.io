(function () {
    "use strict";

    const MINUTE_MS = 60000;
    let phase = "idle";
    let rafId = null;
    let runStart = 0;
    let times = [];
    let idCounter = 1;

    const clockEl = document.getElementById("clock");
    const hintEl = document.getElementById("hint");
    const timesListEl = document.getElementById("timesList");
    const graphCanvas = document.getElementById("graph");
    const ctx = graphCanvas.getContext("2d");

    function formatMs(ms) {
        const minutes = Math.floor(ms / 60000);
        const seconds = Math.floor((ms % 60000) / 1000);
        const millis = Math.floor(ms % 1000);
        return `${minutes}:${String(seconds).padStart(2, "0")}.${String(millis).padStart(3, "0")}`;
    }

    function goIdle() {
        phase = "idle";
        cancelAnimationFrame(rafId);
        clockEl.classList.remove("active");
        clockEl.textContent = "0:00.000";
        hintEl.textContent = "space to start";
    }

    function startRun() {
        phase = "running";
        clockEl.classList.add("active");
        hintEl.textContent = "space to stop";
        runStart = performance.now();
        tickRun();
    }

    function tickRun() {
        if (phase !== "running") return;
        const elapsed = performance.now() - runStart;
        clockEl.textContent = formatMs(elapsed);
        rafId = requestAnimationFrame(tickRun);
    }

    function stopRun() {
        if (phase !== "running") return;
        cancelAnimationFrame(rafId);
        const elapsed = performance.now() - runStart;
        clockEl.textContent = formatMs(elapsed);
        clockEl.classList.remove("active");
        addTime(elapsed);
        hintEl.textContent = "space to start";
        phase = "idle";
    }

    window.addEventListener("keydown", (e) => {
        if (e.code !== "Space") return;
        e.preventDefault();
        if (e.repeat) return;
        if (phase === "running") stopRun();
        else if (phase === "idle") startRun();
    });

    const STORAGE_KEY = "stopwatch-times";

    function saveTimes() {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(times.map((t) => t.ms)));
        } catch (e) { }
    }

    function loadTimes() {
        try {
            const raw = localStorage.getItem(STORAGE_KEY);
            if (!raw) return;
            const arr = JSON.parse(raw);
            if (Array.isArray(arr)) {
                arr.forEach((v) => {
                    const n = Number(v);
                    if (!isNaN(n) && n >= 0) times.push({ id: idCounter++, ms: n });
                });
            }
        } catch (e) { /* ignore problems */ }
    }

    function addTime(ms) { times.push({ id: idCounter++, ms }); saveTimes(); renderAll(); }
    function removeTime(id) { times = times.filter((t) => t.id !== id); saveTimes(); renderAll(); }
    function clearAll() {
        if (times.length === 0) return;
        if (!confirm("clear all times?")) return;
        times = [];
        saveTimes();
        renderAll();
    }

    function exportTimes() {
        const text = times.map((t) => t.ms).join("\n");
        const blob = new Blob([text], { type: "text/plain" });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = "times.txt";
        a.click();
        URL.revokeObjectURL(url);
    }

    function importTimes(file) {
        const reader = new FileReader();
        reader.onload = () => {
            const lines = reader.result.split("\n");
            let added = 0;
            lines.forEach((line) => {
                const n = Number(line.trim());
                if (!isNaN(n) && line.trim() !== "" && n >= 0) {
                    times.push({ id: idCounter++, ms: n });
                    added++;
                }
            });
            if (added === 0) alert("No valid times found. Expecting one millisecond value per line.");
            saveTimes();
            renderAll();
        };
        reader.readAsText(file);
    }

    document.getElementById("btnExport").addEventListener("click", exportTimes);
    document.getElementById("btnClear").addEventListener("click", clearAll);
    document.getElementById("btnImport").addEventListener("click", () => document.getElementById("fileInput").click());
    document.getElementById("fileInput").addEventListener("change", (e) => {
        const file = e.target.files[0];
        if (file) importTimes(file);
        e.target.value = "";
    });

    function renderList() {
        timesListEl.innerHTML = "";
        const reversed = times.slice().reverse();
        reversed.forEach((t, i) => {
            const li = document.createElement("li");
            li.className = "time-row";
            const attemptNo = times.length - i;
            li.innerHTML = `<span>#${attemptNo} ${formatMs(t.ms)}</span><button class="del" data-id="${t.id}">×</button>`;
            timesListEl.appendChild(li);
        });
        timesListEl.querySelectorAll(".del").forEach((btn) => {
            btn.addEventListener("click", () => removeTime(Number(btn.dataset.id)));
        });
    }

    function mean(arr) { return arr.reduce((a, b) => a + b, 0) / arr.length; }
    function median(arr) {
        const s = arr.slice().sort((a, b) => a - b);
        const mid = Math.floor(s.length / 2);
        return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
    }
    function stddev(arr) {
        const m = mean(arr);
        return Math.sqrt(mean(arr.map((v) => (v - m) ** 2)));
    }
    function trimmedMean(arr) {
        const s = arr.slice().sort((a, b) => a - b);
        return mean(s.slice(1, s.length - 1));
    }
    function bestWindowTrimmedMean(arr, size) {
        if (arr.length < size) return null;
        let best = Infinity;
        for (let i = 0; i <= arr.length - size; i++) {
            const tm = trimmedMean(arr.slice(i, i + size));
            if (tm < best) best = tm;
        }
        return best;
    }
    function setStat(id, val) {
        document.getElementById(id).textContent = val === null || val === undefined ? "—" : formatMs(val);
    }

    function renderStats() {
        const chrono = times.map((t) => t.ms);
        if (chrono.length === 0) {
            ["statBest","statWorst","statAvg","statMedian","statDev",
                "statAvg5","stat3of5","statBest3of5",
                "statAvg12","stat10of12","statBest10of12"].forEach((id) => setStat(id, null));
            return;
        }
        setStat("statBest", Math.min(...chrono));
        setStat("statWorst", Math.max(...chrono));
        setStat("statAvg", mean(chrono));
        setStat("statMedian", median(chrono));
        setStat("statDev", chrono.length > 1 ? stddev(chrono) : 0);

        if (chrono.length >= 5) {
            const last5 = chrono.slice(-5);
            setStat("statAvg5", mean(last5));
            setStat("stat3of5", trimmedMean(last5));
            setStat("statBest3of5", bestWindowTrimmedMean(chrono, 5));
        } else {
            setStat("statAvg5", null); setStat("stat3of5", null); setStat("statBest3of5", null);
        }
        if (chrono.length >= 12) {
            const last12 = chrono.slice(-12);
            setStat("statAvg12", mean(last12));
            setStat("stat10of12", trimmedMean(last12));
            setStat("statBest10of12", bestWindowTrimmedMean(chrono, 12));
        } else {
            setStat("statAvg12", null); setStat("stat10of12", null); setStat("statBest10of12", null);
        }
    }

    function resizeCanvas() {
        const rect = graphCanvas.getBoundingClientRect();
        const dpr = window.devicePixelRatio || 1;
        graphCanvas.width = rect.width * dpr;
        graphCanvas.height = rect.height * dpr;
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }

    function renderGraph() {
        resizeCanvas();
        const w = graphCanvas.clientWidth;
        const h = graphCanvas.clientHeight;
        ctx.clearRect(0, 0, w, h);

        const padL = 34, padR = 6, padT = 8, padB = 16;
        const plotW = w - padL - padR;
        const plotH = h - padT - padB;

        ctx.strokeStyle = "rgba(237,227,234,0.15)";
        ctx.fillStyle = "rgba(237,227,234,0.6)";
        ctx.font = "9px 'JetBrains Mono', monospace";
        ctx.textAlign = "right";
        ctx.textBaseline = "middle";

        const vals = times.map((t) => t.ms);
        const maxVal = vals.length ? Math.max(...vals) : 1000;
        const niceMax = maxVal * 1.1 || 1000;

        for (let i = 0; i <= 3; i++) {
            const v = (niceMax / 3) * i;
            const y = padT + plotH - (v / niceMax) * plotH;
            ctx.beginPath(); ctx.moveTo(padL, y); ctx.lineTo(w - padR, y); ctx.stroke();
            ctx.fillText(Math.round(v).toString(), padL - 5, y);
        }

        if (times.length === 0) return;

        const n = times.length;
        ctx.beginPath();
        ctx.strokeStyle = getComputedStyle(document.documentElement).getPropertyValue("--accent").trim();
        ctx.lineWidth = 2;
        times.forEach((t, i) => {
            const x = n === 1 ? padL + plotW / 2 : padL + (i / (n - 1)) * plotW;
            const y = padT + plotH - (t.ms / niceMax) * plotH;
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        });
        ctx.stroke();
    }

    function renderAll() { renderList(); renderStats(); renderGraph(); }
    window.addEventListener("resize", renderGraph);

    loadTimes();
    goIdle();
    renderAll();
})();
