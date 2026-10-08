/*  Reforged Tips: After Effects builder
    ------------------------------------------------------------
    File > Scripts > Run Script File... and pick this file.
    It must sit in  Marketing/Tips/ae/  so it can find:
        ../screens/<name>.mov|.mp4   (your iPhone screen recordings, optional)
        ../vo/<tip-id>.mp3|.wav      (voiceover, optional)
        ./logo-mark.png              (charcoal R mark)
    Install ./fonts/ArchivoBlack-Regular.ttf first (titles).
    Builds, per tip:  16x9 master (1920x1080) + 9x16 social cut (1080x1920)
    and queues everything for render into ../renders/.
    Re-run any time: it builds into a fresh project folder, nothing is overwritten.
*/

(function () {

var DATA = __TIPS_JSON__;

// ---------------------------------------------------------------- settings
var FPS = 30;
var T = {
    hookEnd: 4.6,        // full-screen title card
    wipe: 0.7,           // paper wipe over the B-roll
    titleIn: 5.0,
    phoneIn: 5.5,
    stepsStart: 7.0,
    stepLen: 7.0,        // seconds per step
    outroLen: 5.5
};
var C = {
    paper: "#FAF8F5", card: "#FFFFFF", sunken: "#EFEDE9", charcoal: "#333333",
    ink: "#2D2D2D", ink2: "#666666", ink3: "#9A9A9C", coral: "#E94560",
    gold: "#D4A574", goldDeep: "#B07F4E", cream: "#E8E4DC"
};
var FONTS = {
    display: ["ArchivoBlack-Regular", "Archivo-Black", "HelveticaNeue-CondensedBlack", "Helvetica-Bold"],
    serif: ["LibreBaskerville-Bold", "LibreBaskerville_700wght", "NewYorkLarge-Bold", "Georgia-Bold"],
    label: ["SFProText-Bold", "Roboto-Bold", "Roboto_700wght", "HelveticaNeue-Bold"],
    body:  ["SFProDisplay-Regular", "Roboto-Regular", "HelveticaNeue"],
    bodyStrong: ["SFProDisplay-Semibold", "Roboto-Medium", "Roboto_500wght", "HelveticaNeue-Medium"]
};

// ---------------------------------------------------------------- paths
var AE_DIR = new File($.fileName).parent;
var ROOT = AE_DIR.parent;
function p(rel) { return new File(ROOT.fsName + "/" + rel); }

// ---------------------------------------------------------------- helpers
function hex(h) {
    h = h.replace("#", "");
    return [parseInt(h.substr(0, 2), 16) / 255, parseInt(h.substr(2, 2), 16) / 255, parseInt(h.substr(4, 2), 16) / 255];
}
function pad2(n) { return (n < 10 ? "0" : "") + n; }

var fontCache = {};
function pickFont(key) {
    if (fontCache[key]) return fontCache[key];
    var list = FONTS[key], chosen = list[list.length - 1];
    try {
        if (app.fonts && app.fonts.getFontsByPostScriptName) {
            for (var i = 0; i < list.length; i++) {
                var hits = app.fonts.getFontsByPostScriptName(list[i]);
                if (hits && hits.length) { chosen = list[i]; break; }
            }
        } else { chosen = list[0]; }
    } catch (e) { chosen = list[0]; }
    fontCache[key] = chosen;
    return chosen;
}

function easeAll(prop, inflIn, inflOut) {
    for (var k = 1; k <= prop.numKeys; k++) {
        var t = prop.propertyValueType;
        var dims = (t === PropertyValueType.ThreeD) ? 3 : (t === PropertyValueType.TwoD ? 2 : 1);
        var eIn = [], eOut = [];
        for (var d = 0; d < dims; d++) { eIn.push(new KeyframeEase(0, inflIn)); eOut.push(new KeyframeEase(0, inflOut)); }
        try { prop.setTemporalEaseAtKey(k, eIn, eOut); } catch (e) {}
    }
}
// keys: [[time, value], ...]  -> smooth "ease out expo"-ish curve
function anim(prop, keys, soft) {
    for (var i = 0; i < keys.length; i++) prop.setValueAtTime(keys[i][0], keys[i][1]);
    easeAll(prop, soft ? 60 : 85, soft ? 60 : 85);
}
function tr(layer, name) { return layer.property("ADBE Transform Group").property(name); }
function pos(l) { return tr(l, "ADBE Position"); }
function opa(l) { return tr(l, "ADBE Opacity"); }
function scl(l) { return tr(l, "ADBE Scale"); }

function fadeIn(l, t, dur, fromOffset) {
    anim(opa(l), [[t, 0], [t + (dur || 0.5), 100]]);
    if (fromOffset) {
        var v = pos(l).value;
        anim(pos(l), [[t, [v[0] + fromOffset[0], v[1] + fromOffset[1]]], [t + (dur || 0.5) + 0.2, [v[0], v[1]]]]);
    }
}
function fadeOut(l, t, dur) {
    var o = opa(l);
    var cur = o.numKeys ? o.valueAtTime(t, false) : o.value;
    o.setValueAtTime(t, cur);
    o.setValueAtTime(t + (dur || 0.4), 0);
    easeAll(o, 85, 85);
}

function roundRect(comp, name, w, h, r, color, xy) {
    var l = comp.layers.addShape();
    l.name = name;
    var g = l.property("ADBE Root Vectors Group").addProperty("ADBE Vector Group");
    var c = g.property("ADBE Vectors Group");
    var rect = c.addProperty("ADBE Vector Shape - Rect");
    rect.property("ADBE Vector Rect Size").setValue([w, h]);
    rect.property("ADBE Vector Rect Roundness").setValue(r);
    var f = c.addProperty("ADBE Vector Graphic - Fill");
    f.property("ADBE Vector Fill Color").setValue(hex(color));
    pos(l).setValue(xy);
    return l;
}
function circle(comp, name, d, color, xy) {
    var l = comp.layers.addShape();
    l.name = name;
    var g = l.property("ADBE Root Vectors Group").addProperty("ADBE Vector Group");
    var c = g.property("ADBE Vectors Group");
    c.addProperty("ADBE Vector Shape - Ellipse").property("ADBE Vector Ellipse Size").setValue([d, d]);
    c.addProperty("ADBE Vector Graphic - Fill").property("ADBE Vector Fill Color").setValue(hex(color));
    pos(l).setValue(xy);
    return l;
}
function softShadow(l, strength, dist, soft) {
    try {
        var fx = l.property("ADBE Effect Parade").addProperty("ADBE Drop Shadow");
        fx.property("ADBE Drop Shadow-0001").setValue([0, 0, 0, 1]);
        fx.property("ADBE Drop Shadow-0002").setValue(strength || 26);   // 0-255 (≈10%)
        fx.property("ADBE Drop Shadow-0003").setValue(180);
        fx.property("ADBE Drop Shadow-0004").setValue(dist || 14);
        fx.property("ADBE Drop Shadow-0005").setValue(soft || 48);
    } catch (e) {}
}

// o: {font, size, color, box:[w,h], center:bool, tracking, leading, caps}
function text(comp, str, o, xy) {
    var l = o.box ? comp.layers.addBoxText([o.box[0], o.box[1]], str) : comp.layers.addText(str);
    var prop = l.property("ADBE Text Properties").property("ADBE Text Document");
    var d = prop.value;
    try { d.resetCharStyle(); d.resetParagraphStyle(); } catch (e) {}
    d.text = str;
    d.fontSize = o.size;
    d.applyFill = true; d.applyStroke = false;
    d.fillColor = hex(o.color);
    try { d.font = pickFont(o.font); } catch (e) {}
    d.justification = o.center ? ParagraphJustification.CENTER_JUSTIFY : ParagraphJustification.LEFT_JUSTIFY;
    if (o.tracking) d.tracking = o.tracking;
    if (o.leading) { try { d.autoLeading = false; d.leading = o.leading; } catch (e) {} }
    if (o.caps) { try { d.allCaps = true; } catch (e) {} }
    if (o.box) { try { d.boxTextPos = [-o.box[0] / 2, -o.box[1] / 2]; } catch (e) {} }
    prop.setValue(d);
    pos(l).setValue(xy);
    l.name = str.length > 30 ? str.substr(0, 30) + "…" : str;
    return l;
}

function importIfExists(file) {
    if (!file.exists) return null;
    try { return app.project.importFile(new ImportOptions(file)); } catch (e) { return null; }
}
function findMedia(relNoExt, exts) {
    for (var i = 0; i < exts.length; i++) {
        var f = p(relNoExt + exts[i]);
        if (f.exists) return f;
    }
    return null;
}
function stripExt(s) { return s.replace(/\.[^.\/]+$/, ""); }

function setMatte(layer, matte) {
    // matte must sit directly above layer (legacy), works on new API too
    try {
        if (layer.setTrackMatte) { layer.setTrackMatte(matte, TrackMatteType.ALPHA); return; }
    } catch (e) {}
    layer.trackMatteType = TrackMatteType.ALPHA;
}
function coverScale(item, w, h) {
    var s = Math.max(w / item.width, h / item.height) * 100;
    return [s, s];
}

// ---------------------------------------------------------------- project setup
app.beginUndoGroup("Build Reforged Tips");
var proj = app.project || app.newProject();
var stamp = new Date();
var rootFolder = proj.items.addFolder("Reforged Tips " + stamp.getFullYear() + "-" + pad2(stamp.getMonth() + 1) + "-" + pad2(stamp.getDate()));
var fMedia = proj.items.addFolder("Media"); fMedia.parentFolder = rootFolder;
var fScreens = proj.items.addFolder("Screens (precomps)"); fScreens.parentFolder = rootFolder;
var fMasters = proj.items.addFolder("16x9 Masters"); fMasters.parentFolder = rootFolder;
var fSocial = proj.items.addFolder("9x16 Social"); fSocial.parentFolder = rootFolder;

var logoItem = importIfExists(new File(AE_DIR.fsName + "/logo-mark.png"));
if (logoItem) logoItem.parentFolder = fMedia;

var catById = {};
for (var ci = 0; ci < DATA.categories.length; ci++) {
    var cat = DATA.categories[ci];
    catById[cat.id] = cat;
}

var missing = [];

// ---------------------------------------------------------------- screen precomp
// 780 x 1688 = iPhone logical 390x844 @2x. Screens swap halfway through the steps.
var SW = 780, SH = 1688, SR = 110;
function buildScreen(tip, dur) {
    var comp = proj.items.addComp("Screen · " + tip.id, SW, SH, 1, dur, FPS);
    comp.parentFolder = fScreens;
    comp.bgColor = hex(C.paper);
    var bg = comp.layers.addSolid(hex(C.paper), "paper", SW, SH, 1, dur);
    var half = dur / 2;
    for (var s = 0; s < tip.screens.length; s++) {
        var rel = tip.screens[s];
        var start = s === 0 ? 0 : half;
        var end = s === 0 ? half + 0.4 : dur;
        var f = findMedia(stripExt(rel), [".mov", ".mp4", ".MOV", ".MP4", ".png", ".jpg"]);
        var item = f ? importIfExists(f) : null;
        var l;
        if (item) {
            item.parentFolder = fMedia;
            l = comp.layers.add(item);
            scl(l).setValue(coverScale(item, SW, SH));
            pos(l).setValue([SW / 2, SH / 2]);
        } else {
            missing.push(rel);
            var ph = comp.layers.addSolid(hex(s === 0 ? C.card : C.sunken), "PLACEHOLDER " + rel, SW, SH, 1, dur);
            l = ph;
            var lbl = text(comp, "Drop screen recording\n" + rel, {font: "bodyStrong", size: 34, color: C.ink3, center: true, box: [SW - 120, 200]}, [SW / 2, SH / 2]);
            lbl.inPoint = start; lbl.outPoint = end;
        }
        l.inPoint = start; l.outPoint = end;
        if (s > 0) anim(opa(l), [[start, 0], [start + 0.4, 100]]);
    }
    // rounded-corner matte on top of everything
    var matte = roundRect(comp, "screen matte", SW, SH, SR, C.card, [SW / 2, SH / 2]);
    var pre = comp.layers.precompose(range(2, comp.numLayers), "Screen content · " + tip.id, true);
    pre.parentFolder = fScreens;
    var content = comp.layer(2);
    setMatte(content, comp.layer(1));
    return comp;
}
function range(a, b) { var r = []; for (var i = a; i <= b; i++) r.push(i); return r; }

// ---------------------------------------------------------------- tip comp
function buildTip(tip, vertical) {
    var cat = catById[tip.category];
    var W = vertical ? 1080 : 1920, H = vertical ? 1920 : 1080;
    var nSteps = tip.steps.length;
    var stepsEnd = T.stepsStart + nSteps * T.stepLen;
    var outroStart = stepsEnd + 0.4;
    var dur = outroStart + T.outroLen;

    var comp = proj.items.addComp("Tip " + pad2(tip.number) + " · " + tip.title + (vertical ? " · 9x16" : " · 16x9"), W, H, 1, dur, FPS);
    comp.parentFolder = vertical ? fSocial : fMasters;
    comp.bgColor = hex(C.paper);

    // ---- base paper
    comp.layers.addSolid(hex(C.paper), "paper", W, H, 1, dur);

    // ---- full-screen title card (charcoal, Archivo Black)
    var eyebrowTxt = "TIP " + pad2(tip.number) + "  ·  " + cat.title.toUpperCase();
    var cardOut = T.hookEnd + T.wipe + 0.1;
    var FL = vertical ? 90 : 150, FW = W - FL * 2;
    var tcBg = comp.layers.addSolid(hex(C.charcoal), "title card", W, H, 1, dur);
    tcBg.outPoint = cardOut;

    var tcEy = text(comp, eyebrowTxt, {font: "label", size: vertical ? 30 : 26, color: C.gold, tracking: 180, box: [FW, 48]}, [FL + FW / 2, 0]);
    var tcTitle = text(comp, tip.title.toUpperCase(), {font: "display", size: vertical ? 100 : 118, color: C.cream,
        leading: vertical ? 104 : 118, tracking: -10, box: [FW, vertical ? 1000 : 600]}, [FL + FW / 2, 0]);
    var tcHook = text(comp, tip.hook, {font: "body", size: vertical ? 42 : 38, color: C.cream, leading: vertical ? 56 : 50,
        box: [vertical ? FW : 1100, 180]}, [FL + (vertical ? FW : 1100) / 2, 0]);
    opa(tcHook).setValue(70);

    // measure real text heights, then centre the whole block vertically
    function rectOf(l) { try { return l.sourceRectAtTime(1, false); } catch (e) { return {top: 0, height: 100}; } }
    var rEy = rectOf(tcEy), rTi = rectOf(tcTitle), rHo = rectOf(tcHook);
    var gap1 = vertical ? 44 : 40, gap2 = vertical ? 56 : 48;
    var blockH = 8 + 30 + rEy.height + gap1 + rTi.height + gap2 + rHo.height;
    var y = (H - blockH) / 2;
    var tcRule = roundRect(comp, "title rule", 72, 8, 4, cat.color || C.coral, [FL + 36, y + 4]);
    y += 8 + 30;
    pos(tcEy).setValue([FL + FW / 2, y - rEy.top]);            y += rEy.height + gap1;
    pos(tcTitle).setValue([FL + FW / 2, y - rTi.top]);         y += rTi.height + gap2;
    pos(tcHook).setValue([FL + (vertical ? FW : 1100) / 2, y - rHo.top]);

    fadeIn(tcRule, 0.25, 0.45, [-40, 0]);
    fadeIn(tcEy, 0.35, 0.5, [0, 24]);
    fadeIn(tcTitle, 0.5, 0.7, [0, 60]);
    anim(opa(tcHook), [[1.3, 0], [1.9, 70]]);
    var hv = pos(tcHook).value;
    anim(pos(tcHook), [[1.3, [hv[0], hv[1] + 24]], [2.1, [hv[0], hv[1]]]]);
    var tcLayers = [tcRule, tcEy, tcTitle, tcHook];
    for (var tl = 0; tl < tcLayers.length; tl++) tcLayers[tl].outPoint = cardOut;
    // subtle lift of the title block as the paper wipes in
    for (var tl2 = 1; tl2 < tcLayers.length; tl2++) {
        var pv = pos(tcLayers[tl2]);
        var cur = pv.valueAtTime(T.hookEnd, false);
        pv.setValueAtTime(T.hookEnd, cur);
        pv.setValueAtTime(T.hookEnd + T.wipe, [cur[0], cur[1] - 80]);
        easeAll(pv, 85, 85);
    }

    // ---- paper wipe (slides up over the title card)
    var wipe = comp.layers.addSolid(hex(C.paper), "paper wipe", W, H, 1, dur);
    anim(pos(wipe), [[T.hookEnd, [W / 2, H * 1.5]], [T.hookEnd + T.wipe, [W / 2, H / 2]]]);

    // ---- title block
    var L = vertical ? 90 : 150;
    var titleW = vertical ? W - 180 : 820;
    var eyY = vertical ? 190 : 170;
    var ey = text(comp, eyebrowTxt, {font: "label", size: vertical ? 26 : 22, color: C.goldDeep, tracking: 160, box: [titleW, 44]}, [L + titleW / 2, eyY + 22]);
    var title = text(comp, tip.title.toUpperCase(), {font: "display", size: vertical ? 56 : 46, color: C.ink, leading: vertical ? 62 : 52,
        tracking: -5, box: [titleW, vertical ? 190 : 170]}, [L + titleW / 2, eyY + 60 + (vertical ? 95 : 85)]);
    var accent = roundRect(comp, "accent rule", 64, 6, 3, cat.color || C.coral, [L + 32, eyY - 18]);
    fadeIn(accent, T.titleIn, 0.4, [-30, 0]);
    fadeIn(ey, T.titleIn + 0.05, 0.5, [0, 24]);
    fadeIn(title, T.titleIn + 0.15, 0.6, [0, 36]);

    // ---- phone
    var screenDur = dur - T.phoneIn;
    var screen = buildScreen(tip, screenDur);
    var phoneH = vertical ? 1000 : 860;
    var s = phoneH / SH;
    var phoneXY = vertical ? [W / 2, 1010] : [W - 150 - (SW * s) / 2 - 40, H / 2 + 10];
    var bezel = roundRect(comp, "phone bezel", SW * s + 24, SH * s + 24, SR * s + 12, C.charcoal, phoneXY);
    softShadow(bezel, 55, 24, 80);
    var sl = comp.layers.add(screen);
    sl.startTime = T.phoneIn;
    scl(sl).setValue([s * 100, s * 100]);
    pos(sl).setValue(phoneXY);
    sl.parent = bezel;
    anim(pos(bezel), [[T.phoneIn, [phoneXY[0], phoneXY[1] + 140]], [T.phoneIn + 0.9, phoneXY]]);
    anim(opa(bezel), [[T.phoneIn, 0], [T.phoneIn + 0.4, 100]]);
    anim(opa(sl), [[T.phoneIn, 0], [T.phoneIn + 0.4, 100]]);

    // ---- steps
    var stepLayers = [];
    for (var i = 0; i < nSteps; i++) {
        var t0 = T.stepsStart + i * T.stepLen, t1 = t0 + T.stepLen;
        var numD = vertical ? 64 : 56;
        var rowXY, txtBox, txtXY;
        if (vertical) {
            // one caption at a time, bottom of frame
            rowXY = [L + numD / 2, 1640];
            txtBox = [W - L * 2 - numD - 30, 200];
            txtXY = [L + numD + 30 + txtBox[0] / 2, 1640 + 70];
        } else {
            var rowY = 460 + i * 160;
            rowXY = [L + numD / 2, rowY];
            txtBox = [720, 150];
            txtXY = [L + numD + 32 + txtBox[0] / 2, rowY + 50];
        }
        var dot = circle(comp, "step " + (i + 1) + " dot", numD, cat.color || C.coral, rowXY);
        var num = text(comp, String(i + 1), {font: "label", size: vertical ? 30 : 26, color: "#FFFFFF", center: true}, [rowXY[0], rowXY[1] + (vertical ? 11 : 9)]);
        num.parent = dot;
        var st = text(comp, tip.steps[i], {font: "body", size: vertical ? 40 : 32, color: C.ink, leading: vertical ? 54 : 44, box: txtBox}, txtXY);
        stepLayers.push([dot, num, st]);

        anim(scl(dot), [[t0, [0, 0, 100]], [t0 + 0.45, [100, 100, 100]]]);
        fadeIn(st, t0 + 0.1, 0.5, [0, 24]);
        if (vertical) {
            if (i < nSteps - 1) { fadeOut(st, t1 - 0.35, 0.3); fadeOut(dot, t1 - 0.35, 0.3); }
            else { fadeOut(st, stepsEnd, 0.4); fadeOut(dot, stepsEnd, 0.4); }
        } else {
            // dim finished steps so the active one leads
            if (i < nSteps - 1) {
                var o = opa(st);
                o.setValueAtTime(t1, 100); o.setValueAtTime(t1 + 0.4, 38); easeAll(o, 85, 85);
                var od = opa(dot);
                od.setValueAtTime(t1, 100); od.setValueAtTime(t1 + 0.4, 45); easeAll(od, 85, 85);
            }
        }
    }

    // ---- footer mark
    var footer = [];
    if (logoItem) {
        var lg = comp.layers.add(logoItem);
        var ls = (vertical ? 56 : 44) / logoItem.height * 100;
        scl(lg).setValue([ls, ls]);
        pos(lg).setValue(vertical ? [W / 2 - 75, 100] : [L + 18, H - 80]);
        fadeIn(lg, T.titleIn + 0.3, 0.5);
        footer.push(lg);
    }
    var wm = text(comp, "Reforged", {font: "label", size: vertical ? 32 : 26, color: C.charcoal},
        vertical ? [W / 2 - 40, 100 + 11] : [L + 50, H - 80 + 9]);
    fadeIn(wm, T.titleIn + 0.35, 0.5);
    footer.push(wm);

    // ---- clear the stage for the outro
    var stage = [ey, title, accent, bezel, sl].concat(footer);
    for (var k = 0; k < stepLayers.length; k++) stage = stage.concat(stepLayers[k]);
    for (var q = 0; q < stage.length; q++) {
        if (stage[q] === sl) continue; // parented to bezel, follows it
        fadeOut(stage[q], stepsEnd, 0.4);
    }
    fadeOut(sl, stepsEnd, 0.4);

    // ---- outro
    var cy = H / 2 - (vertical ? 80 : 40);
    if (logoItem) {
        var ol = comp.layers.add(logoItem);
        var os = (vertical ? 190 : 150) / logoItem.height * 100;
        pos(ol).setValue([W / 2, cy - (vertical ? 170 : 130)]);
        anim(scl(ol), [[outroStart, [os * 0.85, os * 0.85]], [outroStart + 0.6, [os, os]]]);
        anim(opa(ol), [[outroStart, 0], [outroStart + 0.4, 100]]);
    }
    var o1 = text(comp, "REFORGED", {font: "display", size: vertical ? 84 : 72, color: C.ink, center: true}, [W / 2, cy + 20]);
    var o2 = text(comp, "Read it. Memorize it. Live it.", {font: "body", size: vertical ? 40 : 34, color: C.ink2, center: true}, [W / 2, cy + (vertical ? 100 : 86)]);
    var pill = roundRect(comp, "cta pill", vertical ? 640 : 560, vertical ? 88 : 72, 999, C.coral, [W / 2, cy + (vertical ? 250 : 200)]);
    var o3 = text(comp, "Free on iOS and Android", {font: "bodyStrong", size: vertical ? 36 : 30, color: "#FFFFFF", center: true}, [W / 2, cy + (vertical ? 250 : 200) + (vertical ? 13 : 11)]);
    fadeIn(o1, outroStart + 0.15, 0.5, [0, 24]);
    fadeIn(o2, outroStart + 0.3, 0.5, [0, 24]);
    fadeIn(pill, outroStart + 0.45, 0.5, [0, 24]);
    fadeIn(o3, outroStart + 0.5, 0.5, [0, 24]);

    // ---- voiceover (optional)
    var vf = findMedia("vo/" + tip.id, [".mp3", ".wav", ".m4a", ".aif"]);
    var vi = vf ? importIfExists(vf) : null;
    if (vi) {
        vi.parentFolder = fMedia;
        var vl = comp.layers.add(vi);
        vl.startTime = T.titleIn + 0.2;
        vl.moveToEnd();
        if (vi.duration + vl.startTime > stepsEnd) {
            // stretch the step timing is not automatic; flag it
            vl.comment = "VO runs past the steps (" + (vi.duration + vl.startTime).toFixed(1) + "s). Increase T.stepLen.";
        }
    }

    // ---- render queue
    try {
        var rq = proj.renderQueue.items.add(comp);
        var om = rq.outputModule(1);
        var h264 = false;
        try { om.applyTemplate("H.264 - Match Render Settings - 15 Mbps"); h264 = true; } catch (e1) {}
        var outName = pad2(tip.number) + "_" + tip.id + (vertical ? "_9x16" : "_16x9");
        var ext = h264 ? ".mp4" : ".mov";
        om.file = new File(ROOT.fsName + "/renders/" + outName + ext);
    } catch (e2) {}

    return comp;
}

// ---------------------------------------------------------------- build all
var rendersDir = new Folder(ROOT.fsName + "/renders");
if (!rendersDir.exists) rendersDir.create();

var built = 0;
for (var ti = 0; ti < DATA.tips.length; ti++) {
    buildTip(DATA.tips[ti], false);
    buildTip(DATA.tips[ti], true);
    built += 2;
}
app.endUndoGroup();

// de-dupe the missing list
var seen = {}, uniq = [];
for (var m = 0; m < missing.length; m++) if (!seen[missing[m]]) { seen[missing[m]] = 1; uniq.push(missing[m]); }
var msg = "Built " + built + " comps (16x9 + 9x16) and queued them for render.\n\n";
msg += "Fonts used:\n  display: " + pickFont("display") + "\n  serif: " + pickFont("serif") + "\n  label: " + pickFont("label") + "\n  body: " + pickFont("body") + "\n";
if (uniq.length) msg += "\nPlaceholders used for " + uniq.length + " missing file(s). Add them to the Tips folder and re-run:\n  " + uniq.join("\n  ");
alert(msg, "Reforged Tips");

})();
