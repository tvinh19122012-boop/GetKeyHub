// ==UserScript==
// @name         MINH PHƯƠNG AUTO LINK4M
// @namespace    minhphuong.link4m
// @version      32.0
// @description  Panel mau co rainbow
// @author       MINH PHƯƠNG
// @match        *://*/*
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_deleteValue
// @grant        GM_addStyle
// @run-at       document-idle
// @noframes
// ==/UserScript==

(function () {
    'use strict';

    var HOST = location.hostname;
    var isLink4m = /(^|\.)link4m\.(net|org|com)$/i.test(HOST);
    var isGoogle = /(^|\.)google\./i.test(HOST);

    var CFG = { poll: 100, maxLoops: 90000, gk: 'mp_' };

    var S = {
        get: function(k, d) { try { var v = GM_getValue(CFG.gk + k, d); return v === undefined ? d : v; } catch (e) { return d; } },
        set: function(k, v) { try { GM_setValue(CFG.gk + k, v); } catch (e) {} },
        del: function(k) { try { GM_deleteValue(CFG.gk + k); } catch (e) {} },
        reset: function() {
            var keys = ['state','domain','keyword','mode','link4m','code','targetUrl','returned','lastServerSec','lastPhase','lastTotal','lastClickTime','scrollOn','serverTotalSec','serverTotalSec2','waitReloadStart','filled'];
            for (var i = 0; i < keys.length; i++) S.del(keys[i]);
        }
    };

    var DOMAINS = {
        getList: function() {
            try {
                var raw = S.get('savedDomains', '[]');
                return typeof raw === 'string' ? JSON.parse(raw) : (raw || []);
            } catch (e) { return []; }
        },
        save: function(domain) {
            var d = (domain || '').trim().toLowerCase().replace(/^https?:\/\//, '').replace(/\/.*$/, '');
            if (!d) return false;
            var list = DOMAINS.getList();
            for (var i = 0; i < list.length; i++) if (list[i].d === d) return false;
            list.unshift({ d: d, t: Date.now() });
            if (list.length > 30) list.length = 30;
            S.set('savedDomains', JSON.stringify(list));
            return true;
        },
        remove: function(d) {
            var list = DOMAINS.getList();
            var out = [];
            for (var i = 0; i < list.length; i++) if (list[i].d !== d) out.push(list[i]);
            S.set('savedDomains', JSON.stringify(out));
        }
    };

    function log() {
        var args = Array.prototype.slice.call(arguments);
        console.log.apply(console, ['%c🌸 [MINH PHƯƠNG]', 'color:#ff6b9d;font-weight:700'].concat(args));
    }

    function sleep(ms) { return new Promise(function(r){ setTimeout(r, ms); }); }
    function getState() { return S.get('state', 'idle'); }
    function getMode() { return S.get('mode', 'url'); }
    function setState(s) { S.set('state', s); log('→ STATE:', s); refreshStatus(); }

    function isTargetPage() {
        var t = S.get('targetUrl');
        var curDomain = S.get('domain');
        var ch = HOST.replace(/^www\./, '');
        if (curDomain) {
            var cd = curDomain.toLowerCase().replace(/^www\./, '').replace(/^https?:\/\//, '').replace(/\/.*$/, '');
            if (ch.indexOf(cd) !== -1 || cd.indexOf(ch) !== -1) return true;
        }
        if (!t) return false;
        try {
            var th = new URL(t).hostname.replace(/^www\./, '');
            if (ch.indexOf(th) !== -1 || th.indexOf(ch) !== -1) return true;
        } catch (e) {}
        return false;
    }

    function isRealTargetPage() {
        return !isLink4m && !isGoogle && isTargetPage();
    }

    if (!isLink4m && !isGoogle && !isTargetPage()) return;

    var C = {
        bg1: '#fff0f5', bg2: '#ffe4ec', card: '#ffffff',
        pink: '#ff6b9d', pinkDark: '#c9184a', pinkLight: '#ffb3c6',
        pinkSoft: '#ffe0eb', text: '#3d2c34', textSoft: '#8a6b77', border: '#ffd6e5',
        // Màu cờ rainbow
        r1: '#ff0018', // Đỏ
        r2: '#ffa52c', // Cam
        r3: '#ffff41', // Vàng
        r4: '#008018', // Xanh lá
        r5: '#0000f9', // Xanh dương
        r6: '#86007d'  // Tím
    };

    GM_addStyle(
        '#mp-root{position:fixed;top:8px;right:8px;z-index:2147483647;width:auto;max-width:340px;font-family:Segoe UI,sans-serif;font-size:10px;color:' + C.text + ';border-radius:14px;overflow:hidden;background:linear-gradient(160deg,#fff5fb 0%,#ffffff 50%,#f5faff 100%);box-shadow:0 8px 28px rgba(255,107,157,.35),0 0 0 2px transparent,0 0 0 3px #ff0018,0 0 0 4px #ffa52c,0 0 0 5px #ffff41,0 0 0 6px #008018,0 0 0 7px #0000f9,0 0 0 8px #86007d;user-select:none;max-height:96vh;display:flex;flex-direction:column;transition:max-width .2s,width .2s}' +
        '#mp-root *{box-sizing:border-box}' +
        '#mp-root.mp-min{width:50px !important;max-width:50px !important;border-radius:50% !important;max-height:none}' +
        '#mp-root.mp-min .mp-head{padding:12px 0 !important;text-align:center}' +
        '#mp-root.mp-min .mp-brand{justify-content:center;gap:0}' +
        '#mp-root.mp-min .mp-brand-txt,#mp-root.mp-min .mp-body,#mp-root.mp-min .mp-foot,#mp-root.mp-min .mp-head-actions{display:none}' +
        '#mp-root.mp-min .mp-flower{font-size:24px;margin:0}' +
        '.mp-head{position:relative;padding:10px 14px;color:#fff;cursor:move;background:linear-gradient(90deg,' + C.r1 + ' 0%,' + C.r2 + ' 20%,' + C.r3 + ' 40%,' + C.r4 + ' 60%,' + C.r5 + ' 80%,' + C.r6 + ' 100%);overflow:hidden;touch-action:none;flex-shrink:0}' +
        '.mp-head:after{content:"";position:absolute;top:-20px;right:-20px;width:70px;height:70px;background:radial-gradient(circle,rgba(255,255,255,.35) 0%,transparent 65%);border-radius:50%;pointer-events:none}' +
        '.mp-brand{display:flex;align-items:center;gap:6px;position:relative;z-index:1;text-shadow:0 1px 3px rgba(0,0,0,.6)}' +
        '.mp-flower{font-size:18px;filter:drop-shadow(0 1px 2px rgba(0,0,0,.4))}' +
        '.mp-title-main{font-size:12px;font-weight:900;line-height:1.1}' +
        '.mp-title-sub{font-size:7px;letter-spacing:1.8px;opacity:.98;font-weight:700;margin-top:1px}' +
        '.mp-head-actions{position:absolute;top:6px;right:6px;z-index:3;display:flex;gap:3px}' +
        '.mp-icon-btn{width:20px;height:20px;border-radius:50%;border:2px solid rgba(255,255,255,.5);cursor:pointer;background:rgba(0,0,0,.25);color:#fff;font-size:11px;font-weight:900;display:flex;align-items:center;justify-content:center;line-height:1;padding:0}' +
        '.mp-icon-btn:hover{background:rgba(0,0,0,.4)}' +
        '.mp-body{padding:8px 10px;overflow-y:auto;flex:1;position:relative}' +
        '.mp-body::-webkit-scrollbar{width:3px}' +
        '.mp-body::-webkit-scrollbar-thumb{background:' + C.pinkLight + ';border-radius:3px}' +
        '.mp-rainbow-bar{height:3px;background:linear-gradient(90deg,' + C.r1 + ' 0%,' + C.r2 + ' 20%,' + C.r3 + ' 40%,' + C.r4 + ' 60%,' + C.r5 + ' 80%,' + C.r6 + ' 100%);border-radius:3px;margin-bottom:6px}' +
        '.mp-row{display:flex;gap:5px;align-items:center;margin-bottom:5px}' +
        '.mp-status{background:linear-gradient(90deg,rgba(255,0,24,.05) 0%,rgba(255,165,44,.05) 25%,rgba(255,255,65,.08) 50%,rgba(0,128,24,.05) 75%,rgba(134,0,125,.05) 100%);border-radius:7px;padding:6px 8px;margin-bottom:6px;border-left:4px solid transparent;border-image:linear-gradient(180deg,' + C.r1 + ',' + C.r2 + ',' + C.r3 + ',' + C.r4 + ',' + C.r5 + ',' + C.r6 + ') 1;box-shadow:0 1px 4px rgba(255,107,157,.1);font-size:9px;font-weight:800;color:' + C.pinkDark + ';line-height:1.3;text-align:center}' +
        '.mp-section{background:#fff;border-radius:9px;padding:7px 8px;margin-bottom:6px;box-shadow:0 1px 6px rgba(255,107,157,.12);border:1px solid rgba(255,179,198,.4)}' +
        '.mp-section-title{font-size:8px;font-weight:900;letter-spacing:1px;margin-bottom:5px;background:linear-gradient(90deg,' + C.r1 + ',' + C.r2 + ',' + C.r3 + ',' + C.r4 + ',' + C.r5 + ',' + C.r6 + ');-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}' +
        '.mp-input{flex:1;min-width:0;padding:6px 8px;border:1.5px solid ' + C.pinkLight + ';border-radius:7px;font-family:inherit;font-size:10px;color:' + C.text + ';background:#fff;outline:none;width:100%}' +
        '.mp-input:focus{border-color:' + C.r5 + ';box-shadow:0 0 0 2px rgba(0,0,249,.15)}' +
        '.mp-input::placeholder{color:#c9a4b3}' +
        '.mp-btn{padding:6px 10px;border:none;border-radius:7px;font-weight:800;font-size:9px;cursor:pointer;color:#fff;background:linear-gradient(90deg,' + C.r5 + ' 0%,' + C.r6 + ' 100%);box-shadow:0 2px 8px rgba(0,0,249,.3);font-family:inherit;white-space:nowrap;flex-shrink:0;transition:transform .1s}' +
        '.mp-btn:active{transform:scale(.96)}' +
        '.mp-btn.gray{background:linear-gradient(90deg,#9ca3af,#6b7280);box-shadow:0 2px 8px rgba(107,114,128,.3)}' +
        '.mp-btn.blue{background:linear-gradient(90deg,#3b82f6,#1d4ed8);box-shadow:0 2px 8px rgba(59,130,246,.35)}' +
        '.mp-btn.green{background:linear-gradient(90deg,' + C.r4 + ',#00a020);box-shadow:0 2px 8px rgba(0,128,24,.35)}' +
        '.mp-btn.orange{background:linear-gradient(90deg,' + C.r2 + ',#e67e00);box-shadow:0 2px 8px rgba(255,165,44,.4)}' +
        '.mp-btn.red{background:linear-gradient(90deg,' + C.r1 + ',#cc0014);box-shadow:0 2px 8px rgba(255,0,24,.35)}' +
        '.mp-btn.purple{background:linear-gradient(90deg,' + C.r6 + ',#5e0057);box-shadow:0 2px 8px rgba(134,0,125,.35)}' +
        '.mp-btn.gold{background:linear-gradient(90deg,' + C.r3 + ',#e6e600);color:#333;box-shadow:0 2px 8px rgba(255,255,65,.4)}' +
        '.mp-domain-list{max-height:60px;overflow-y:auto;margin-top:4px;border-radius:6px;background:linear-gradient(90deg,rgba(255,0,24,.03),rgba(134,0,125,.03));padding:3px}' +
        '.mp-domain-item{display:flex;align-items:center;justify-content:space-between;padding:3px 5px;border-radius:4px;font-size:9px;cursor:pointer;margin-bottom:1px;background:#fff}' +
        '.mp-domain-item:hover{background:linear-gradient(90deg,rgba(255,0,24,.05),rgba(134,0,125,.05))}' +
        '.mp-domain-item .d-name{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-weight:700}' +
        '.mp-domain-item .d-use{padding:2px 6px;border-radius:5px;background:linear-gradient(90deg,' + C.r5 + ',' + C.r6 + ');color:#fff;font-size:7px;font-weight:800;border:none;cursor:pointer;margin-left:3px}' +
        '.mp-domain-item .d-del{padding:2px 5px;border-radius:5px;background:linear-gradient(90deg,' + C.r1 + ',#cc0014);color:#fff;font-size:8px;font-weight:900;border:none;cursor:pointer;margin-left:2px}' +
        '.mp-empty{text-align:center;color:' + C.textSoft + ';font-size:8px;padding:6px;font-style:italic}' +
        '.mp-tabs{display:flex;gap:3px;margin-bottom:6px;background:linear-gradient(90deg,rgba(255,0,24,.06),rgba(134,0,125,.06));border-radius:8px;padding:3px}' +
        '.mp-tab{flex:1;padding:6px 4px;border-radius:6px;border:none;background:transparent;color:' + C.textSoft + ';font-family:inherit;font-size:9px;font-weight:800;cursor:pointer;transition:all .2s}' +
        '.mp-tab.active{background:linear-gradient(90deg,' + C.r5 + ' 0%,' + C.r6 + ' 100%);color:#fff;box-shadow:0 2px 8px rgba(0,0,249,.35)}' +
        '.mp-timer{display:none;text-align:center;padding:8px 0 6px;background:#fff;border-radius:8px;margin-bottom:6px;box-shadow:0 1px 6px rgba(255,107,157,.15);border:1px solid rgba(255,179,198,.4)}' +
        '.mp-timer.show{display:flex;align-items:center;justify-content:center;gap:10px}' +
        '.mp-timer-wrap{position:relative;width:52px;height:52px;flex-shrink:0}' +
        '.mp-timer-wrap svg{width:100%;height:100%;transform:rotate(-90deg)}' +
        '.mp-timer-track{fill:none;stroke:#ffe0eb;stroke-width:5}' +
        '.mp-timer-prog{fill:none;stroke:url(#mpGrad);stroke-width:5;stroke-linecap:round;stroke-dasharray:188.5;stroke-dashoffset:0;transition:stroke-dashoffset .15s linear}' +
        '.mp-timer-num{position:absolute;top:0;left:0;right:0;bottom:0;display:flex;align-items:center;justify-content:center;font-size:15px;font-weight:900;color:' + C.pinkDark + ';font-variant-numeric:tabular-nums}' +
        '.mp-timer-cap{font-size:9px;font-weight:800;color:' + C.pinkDark + ';line-height:1.35;text-align:left}' +
        '.mp-guide{display:none;background:linear-gradient(135deg,#fffacd,#fff5b8);border:1.5px solid #ffd84d;border-radius:8px;padding:7px 9px;text-align:center;margin-bottom:6px;font-size:9px;color:#8a6b77;line-height:1.45}' +
        '.mp-guide.show{display:block}' +
        '.mp-guide b{color:' + C.pinkDark + ';font-size:10px}' +
        '.mp-code{display:none;background:linear-gradient(135deg,#fff 0%,#fff0f5 100%);border:2px dashed transparent;border-image:linear-gradient(90deg,' + C.r1 + ',' + C.r2 + ',' + C.r3 + ',' + C.r4 + ',' + C.r5 + ',' + C.r6 + ') 1;border-radius:8px;padding:7px 9px;text-align:center;margin-bottom:6px}' +
        '.mp-code.show{display:block}' +
        '.mp-code-label{font-size:8px;font-weight:900;letter-spacing:1.5px;margin-bottom:4px;background:linear-gradient(90deg,' + C.r1 + ',' + C.r2 + ',' + C.r3 + ',' + C.r4 + ',' + C.r5 + ',' + C.r6 + ');-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}' +
        '.mp-code-value{font-family:Courier New,monospace;font-size:15px;font-weight:900;color:' + C.pinkDark + ';letter-spacing:1px;padding:6px 4px;background:#fff;border-radius:6px;margin-bottom:5px;word-break:break-all;user-select:text;box-shadow:inset 0 0 0 1px rgba(255,179,198,.5)}' +
        '.mp-log{max-height:60px;overflow-y:auto;padding:6px 8px;font-size:8px;font-family:Courier New,monospace;line-height:1.5;color:' + C.textSoft + ';background:linear-gradient(90deg,rgba(255,0,24,.03),rgba(134,0,125,.03));border-radius:7px;border:1px solid rgba(255,179,198,.5)}' +
        '.mp-log::-webkit-scrollbar{width:3px}' +
        '.mp-log::-webkit-scrollbar-thumb{background:' + C.pinkLight + ';border-radius:3px}' +
        '.mp-log div{padding:1px 0;border-bottom:1px dashed rgba(255,179,198,.3)}' +
        '.mp-foot{display:flex;justify-content:center;align-items:center;gap:6px;padding:6px;color:#fff;font-size:8px;font-weight:800;letter-spacing:1.2px;background:linear-gradient(90deg,' + C.r1 + ' 0%,' + C.r2 + ' 20%,' + C.r3 + ' 40%,' + C.r4 + ' 60%,' + C.r5 + ' 80%,' + C.r6 + ' 100%);flex-shrink:0;text-shadow:0 1px 2px rgba(0,0,0,.5)}' +
        '#mp-fab{position:fixed;bottom:20px;right:20px;z-index:2147483647;width:46px;height:46px;border-radius:50%;cursor:pointer;color:#fff;display:flex;align-items:center;justify-content:center;font-size:22px;box-shadow:0 6px 18px rgba(0,0,0,.35);background:linear-gradient(135deg,' + C.r1 + ' 0%,' + C.r2 + ' 20%,' + C.r3 + ' 40%,' + C.r4 + ' 60%,' + C.r5 + ' 80%,' + C.r6 + ' 100%)}' +
        '.mp-hidden{display:none !important}' +
        '.mp-flag{display:inline-block;font-size:11px;margin-right:2px}' +
        '.mp-badge{display:inline-block;padding:1px 5px;border-radius:8px;font-size:7px;font-weight:800;color:#fff;background:linear-gradient(90deg,' + C.r5 + ',' + C.r6 + ');margin-left:3px}'
    );

    var UI = {};
    var loopRunning = false;
    var scrollRAF = null;
    var cachedBtn = null;
    var cachedBtnTime = 0;

    var scrollState = {
        active: false,
        originY: 0,
        offset: 0,
        dir: 1,
        maxOffset: 50,
        step: 0.5,
        lastTime: 0
    };

    function buildPanel() {
        var old = document.getElementById('mp-root');
        if (old) old.remove();
        var root = document.createElement('div');
        root.id = 'mp-root';
        root.innerHTML =
            '<div class="mp-head" id="mp-head">' +
                '<div class="mp-head-actions">' +
                    '<button class="mp-icon-btn" id="mp-min" title="Thu nhỏ">−</button>' +
                    '<button class="mp-icon-btn" id="mp-close" title="Đóng">×</button>' +
                '</div>' +
                '<div class="mp-brand">' +
                    '<div class="mp-flower">🌸</div>' +
                    '<div class="mp-brand-txt">' +
                        '<div class="mp-title-main">🌈 MINH PHƯƠNG🇻🇳</div>' +
                        '<div class="mp-title-sub">AUTO LINK4M v32</div>' +
                    '</div>' +
                '</div>' +
            '</div>' +
            '<div class="mp-body">' +
                '<div class="mp-rainbow-bar"></div>' +
                '<div class="mp-status" id="mp-status">🌈 Sẵn sàng</div>' +
                '<div class="mp-section">' +
                    '<div class="mp-section-title">🌈 CHẾ ĐỘ TÌM KIẾM</div>' +
                    '<div class="mp-tabs">' +
                        '<button class="mp-tab active" id="mp-tab-url" data-mode="url">🔗 URL CỔ ĐIỂN</button>' +
                        '<button class="mp-tab" id="mp-tab-kw" data-mode="keyword">🔑 TỪ KHÓA + URL</button>' +
                    '</div>' +
                    '<div id="mp-mode-url">' +
                        '<input class="mp-input" id="mp-domain-input" type="text" placeholder="vd: sky88.financial" />' +
                    '</div>' +
                    '<div id="mp-mode-kw" class="mp-hidden">' +
                        '<input class="mp-input" id="mp-keyword-input" type="text" placeholder="Từ khóa (vd: soi kèo nhà cái)" style="margin-bottom:4px" />' +
                        '<input class="mp-input" id="mp-url-input-kw" type="text" placeholder="URL web (vd: https://abc.com)" />' +
                    '</div>' +
                    '<div class="mp-row" style="margin-top:5px;margin-bottom:0">' +
                        '<button class="mp-btn blue" id="mp-save-domain" style="flex:1">💾 LƯU</button>' +
                        '<button class="mp-btn green" id="mp-start" style="flex:1">🌈 BẮT ĐẦU</button>' +
                    '</div>' +
                    '<div class="mp-domain-list" id="mp-domain-list"></div>' +
                '</div>' +
                '<div class="mp-row" style="margin-bottom:6px">' +
                    '<button class="mp-btn orange" id="mp-scroll-toggle" style="flex:1">🔄 BẬT LƯỚT</button>' +
                    '<button class="mp-btn gray" id="mp-reset" style="flex:1">🔄 RESET</button>' +
                '</div>' +
                '<div class="mp-timer" id="mp-timer">' +
                    '<div class="mp-timer-wrap">' +
                        '<svg viewBox="0 0 60 60"><defs><linearGradient id="mpGrad" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="' + C.r1 + '"/><stop offset="20%" stop-color="' + C.r2 + '"/><stop offset="40%" stop-color="' + C.r3 + '"/><stop offset="60%" stop-color="' + C.r4 + '"/><stop offset="80%" stop-color="' + C.r5 + '"/><stop offset="100%" stop-color="' + C.r6 + '"/></linearGradient></defs><circle class="mp-timer-track" cx="30" cy="30" r="26"/><circle class="mp-timer-prog" id="mp-timer-prog" cx="30" cy="30" r="26"/></svg>' +
                        '<div class="mp-timer-num" id="mp-timer-num">0</div>' +
                    '</div>' +
                    '<div class="mp-timer-cap" id="mp-timer-cap">ĐANG CHỜ MÃ</div>' +
                '</div>' +
                '<div class="mp-guide" id="mp-guide"></div>' +
                '<div class="mp-code" id="mp-code">' +
                    '<div class="mp-code-label">🌈 MÃ XÁC NHẬN 🌈</div>' +
                    '<div class="mp-code-value" id="mp-code-value">----</div>' +
                    '<button class="mp-btn purple" id="mp-copy" style="width:100%">📋 SAO CHÉP MÃ</button>' +
                '</div>' +
                '<div class="mp-log" id="mp-log"></div>' +
            '</div>' +
            '<div class="mp-foot"><span>🌈</span><span>© MINH PHƯƠNG🇻🇳</span><span>🌈</span></div>';
        document.body.appendChild(root);

        UI = {
            root: root, head: root.querySelector('#mp-head'),
            status: root.querySelector('#mp-status'),
            timer: root.querySelector('#mp-timer'), timerNum: root.querySelector('#mp-timer-num'),
            timerProg: root.querySelector('#mp-timer-prog'), timerCap: root.querySelector('#mp-timer-cap'),
            guide: root.querySelector('#mp-guide'), code: root.querySelector('#mp-code'),
            codeVal: root.querySelector('#mp-code-value'), copy: root.querySelector('#mp-copy'),
            log: root.querySelector('#mp-log'),
            minBtn: root.querySelector('#mp-min'), closeBtn: root.querySelector('#mp-close'),
            domainInput: root.querySelector('#mp-domain-input'),
            keywordInput: root.querySelector('#mp-keyword-input'),
            urlInputKw: root.querySelector('#mp-url-input-kw'),
            modeUrlBox: root.querySelector('#mp-mode-url'),
            modeKwBox: root.querySelector('#mp-mode-kw'),
            tabUrl: root.querySelector('#mp-tab-url'),
            tabKw: root.querySelector('#mp-tab-kw'),
            saveBtn: root.querySelector('#mp-save-domain'),
            startBtn: root.querySelector('#mp-start'), domainList: root.querySelector('#mp-domain-list'),
            scrollToggleBtn: root.querySelector('#mp-scroll-toggle'),
            resetBtn: root.querySelector('#mp-reset')
        };

        UI.tabUrl.onclick = function() { switchMode('url'); };
        UI.tabKw.onclick = function() { switchMode('keyword'); };

        UI.scrollToggleBtn.onclick = function() {
            if (S.get('scrollOn', '0') === '1') stopAutoScroll(); else startAutoScroll();
        };

        UI.resetBtn.onclick = function() {
            if (!confirm('Reset toàn bộ?')) return;
            stopAutoScroll();
            S.reset();
            location.reload();
        };

        UI.copy.onclick = function() {
            var c = UI.codeVal.textContent;
            if (!c || c === '----') return;
            navigator.clipboard.writeText(c).then(function(){
                UI.copy.textContent = '✅ ĐÃ SAO CHÉP!';
                setTimeout(function(){ UI.copy.textContent = '📋 SAO CHÉP MÃ'; }, 1500);
            });
        };

        UI.saveBtn.onclick = function() {
            var mode = getMode();
            if (mode === 'url') {
                var v = UI.domainInput.value.trim();
                if (!v) { UI.domainInput.focus(); return; }
                var ok = DOMAINS.save(v);
                UI.saveBtn.textContent = ok ? '✅ ĐÃ LƯU' : '⚠️ ĐÃ CÓ';
                setTimeout(function(){ UI.saveBtn.textContent = '💾 LƯU'; }, 1200);
                renderDomainList();
            } else {
                var url = UI.urlInputKw.value.trim();
                var kw = UI.keywordInput.value.trim();
                if (!url && !kw) return;
                if (url) {
                    try {
                        var u = new URL(url);
                        DOMAINS.save(u.hostname);
                    } catch (e) {
                        DOMAINS.save(url.replace(/^https?:\/\//, '').replace(/\/.*$/, ''));
                    }
                }
                UI.saveBtn.textContent = '✅ ĐÃ LƯU';
                setTimeout(function(){ UI.saveBtn.textContent = '💾 LƯU'; }, 1200);
                renderDomainList();
            }
        };

        UI.startBtn.onclick = function() {
            var mode = getMode();
            var domain = '';
            var googleUrl = '';

            if (mode === 'url') {
                var v = UI.domainInput.value.trim();
                if (!v) { UI.status.textContent = '⚠️ Nhập domain đích trước!'; UI.domainInput.focus(); return; }
                domain = v.replace(/^https?:\/\//, '').replace(/\/.*$/, '').trim();
                googleUrl = 'https://www.google.com/search?q=' + encodeURIComponent(domain);
                S.set('domain', domain);
                S.set('keyword', '');
                log('🌐 [MODE URL] Mở Google:', googleUrl);
            } else {
                var kw = UI.keywordInput.value.trim();
                var url = UI.urlInputKw.value.trim();
                if (!kw) { UI.status.textContent = '⚠️ Nhập từ khóa trước!'; UI.keywordInput.focus(); return; }
                if (!url) { UI.status.textContent = '⚠️ Nhập URL web trước!'; UI.urlInputKw.focus(); return; }
                try {
                    var u = new URL(url.startsWith('http') ? url : 'https://' + url);
                    domain = u.hostname;
                } catch (e) {
                    domain = url.replace(/^https?:\/\//, '').replace(/\/.*$/, '').trim();
                }
                googleUrl = 'https://www.google.com/search?q=' + encodeURIComponent(kw);
                S.set('domain', domain);
                S.set('keyword', kw);
                log('🔑 [MODE KEYWORD] Từ khóa:', kw, '| URL đích:', domain);
                log('🌐 Mở Google:', googleUrl);
            }

            var newTab = window.open(googleUrl, '_blank');

            S.set('mode', mode);
            S.set('link4m', location.href);
            S.del('returned'); S.del('code'); S.del('targetUrl');
            S.del('lastServerSec'); S.del('lastPhase'); S.del('lastTotal'); S.del('lastClickTime');
            S.del('serverTotalSec'); S.del('serverTotalSec2'); S.del('waitReloadStart'); S.del('filled');
            S.set('state', 'click-google');
            refreshStatus();

            var cont = findContinueBtn();
            if (cont) cont.click();

            if (mode === 'url') DOMAINS.save(domain);
            renderDomainList();

            UI.status.textContent = newTab ? '🔍 Đã mở tab Google' : '⚠️ Cho phép popup!';
        };

        UI.domainInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') UI.startBtn.click();
        });
        UI.keywordInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') UI.urlInputKw.focus();
        });
        UI.urlInputKw.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') UI.startBtn.click();
        });

        var orig = console.log;
        console.log = function() {
            orig.apply(console, arguments);
            if (!UI.log) return;
            var a = Array.prototype.slice.call(arguments);
            var line = a.map(function(x){ return typeof x === 'object' ? JSON.stringify(x) : String(x); }).join(' ');
            var d = document.createElement('div');
            d.textContent = '› ' + line;
            UI.log.appendChild(d);
            UI.log.scrollTop = UI.log.scrollHeight;
            while (UI.log.children.length > 40) UI.log.removeChild(UI.log.firstChild);
        };

        UI.minBtn.onclick = function(e) { e.stopPropagation(); toggleMin(); };
        UI.closeBtn.onclick = function(e) {
            e.stopPropagation();
            UI.root.style.display = 'none';
            var fab = document.getElementById('mp-fab');
            if (!fab) {
                fab = document.createElement('div');
                fab.id = 'mp-fab'; fab.innerHTML = '🌈';
                fab.onclick = function() { UI.root.style.display = ''; fab.remove(); };
                document.body.appendChild(fab);
            }
        };

        if (S.get('min') === '1') { UI.root.classList.add('mp-min'); UI.minBtn.textContent = '+'; }
        var pos = S.get('pos');
        if (pos && typeof pos === 'object') {
            UI.root.style.left = pos.x + 'px'; UI.root.style.top = pos.y + 'px'; UI.root.style.right = 'auto';
        }
        enableDrag();

        var savedMode = getMode();
        switchMode(savedMode);

        var cur = S.get('domain');
        if (cur) UI.domainInput.value = cur;
        var curKw = S.get('keyword');
        if (curKw) UI.keywordInput.value = curKw;

        if (S.get('scrollOn', '0') === '1') setTimeout(function() { startAutoScroll(); }, 500);
        renderDomainList();
    }

    function switchMode(mode) {
        S.set('mode', mode);
        if (mode === 'url') {
            UI.tabUrl.classList.add('active');
            UI.tabKw.classList.remove('active');
            UI.modeUrlBox.classList.remove('mp-hidden');
            UI.modeKwBox.classList.add('mp-hidden');
            log('→ Chế độ: URL CỔ ĐIỂN');
        } else {
            UI.tabUrl.classList.remove('active');
            UI.tabKw.classList.add('active');
            UI.modeUrlBox.classList.add('mp-hidden');
            UI.modeKwBox.classList.remove('mp-hidden');
            log('→ Chế độ: TỪ KHÓA + URL');
        }
    }

    function findL4MFast() {
        if (cachedBtn && Date.now() - cachedBtnTime < 1500) {
            if (document.contains(cachedBtn) && cachedBtn.offsetParent !== null) return cachedBtn;
        }
        var imgs = document.querySelectorAll('img');
        for (var i = 0; i < imgs.length; i++) {
            var img = imgs[i];
            if (img.closest('#mp-root') || img.closest('#mp-fab')) continue;
            var src = (img.src || '').toLowerCase();
            var alt = (img.alt || '').toLowerCase();
            if (src.indexOf('l4m') === -1 && src.indexOf('layma') === -1 && src.indexOf('lay-ma') === -1 &&
                alt.indexOf('l4m') === -1 && alt.indexOf('lấy') === -1) continue;
            var p = img.parentElement; var depth = 0; var best = null;
            while (p && depth < 6) {
                if (p.closest('#mp-root') || p.closest('#mp-fab')) { p = null; break; }
                if (p.offsetParent !== null) {
                    var pt = (p.textContent || '').replace(/\s+/g, ' ').trim();
                    if (pt.length >= 3 && pt.length <= 100 && /lấy\s*mã|lay\s*ma/i.test(pt)) best = p;
                }
                p = p.parentElement; depth++;
            }
            if (best) { cachedBtn = best; cachedBtnTime = Date.now(); return best; }
            if (img.parentElement && img.parentElement.offsetParent !== null) {
                cachedBtn = img.parentElement; cachedBtnTime = Date.now(); return img.parentElement;
            }
        }
        var q = document.querySelectorAll('a, button, [role="button"], [onclick], [onmousedown], [onmouseup], [ontouchstart]');
        for (var j = 0; j < q.length; j++) {
            var el = q[j];
            if (el.closest('#mp-root') || el.closest('#mp-fab')) continue;
            if (el.offsetParent === null) continue;
            var t = (el.textContent || '').replace(/\s+/g, ' ').trim();
            if (t.length < 3 || t.length > 100) continue;
            if (/test|debug|kiểm tra|reset|sao chép|bật lướt|tắt lướt|quét/i.test(t)) continue;
            if (!/lấy\s*mã|lay\s*ma|get\s*code/i.test(t)) continue;
            var inner = (el.innerHTML || '').toLowerCase();
            if (/l4m|lay-?ma/i.test(inner) || el.querySelector('img')) {
                cachedBtn = el; cachedBtnTime = Date.now(); return el;
            }
        }
        var all = document.querySelectorAll('div, span');
        for (var k = 0; k < all.length; k++) {
            var e2 = all[k];
            if (e2.closest('#mp-root') || e2.closest('#mp-fab')) continue;
            if (e2.offsetParent === null) continue;
            var t2 = (e2.textContent || '').replace(/\s+/g, ' ').trim();
            if (t2.length > 100 || t2.length < 3) continue;
            if (/test|debug|kiểm tra|reset|sao chép|bật lướt|tắt lướt|quét/i.test(t2)) continue;
            if (!/lấy\s*mã|lay\s*ma/i.test(t2)) continue;
            var inner2 = (e2.innerHTML || '').toLowerCase();
            var hasL4M = /l4m|lay-?ma/i.test(inner2);
            var hasImg = e2.querySelector('img') !== null;
            try {
                var st = window.getComputedStyle(e2);
                var bg = st.backgroundColor || '';
                var bgImg = st.backgroundImage || '';
                var m = bg.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/);
                var isRed = false;
                if (m) {
                    var R = parseInt(m[1], 10), G = parseInt(m[2], 10), B = parseInt(m[3], 10);
                    if (R > 180 && G < 100 && B < 100) isRed = true;
                }
                if (/gradient/i.test(bgImg) && /rgb\((2[0-5]\d|1[89]\d)/i.test(bgImg)) isRed = true;
                if (isRed && (hasL4M || hasImg)) { cachedBtn = e2; cachedBtnTime = Date.now(); return e2; }
                if (hasL4M && hasImg) { cachedBtn = e2; cachedBtnTime = Date.now(); return e2; }
            } catch (e) {}
        }
        cachedBtn = null;
        return null;
    }

    function findL4MInIframe() {
        var iframes = document.querySelectorAll('iframe');
        for (var i = 0; i < iframes.length; i++) {
            var ifr = iframes[i];
            var src = (ifr.src || '').toLowerCase();
            if (src.indexOf('website-analytics') === -1 && src.indexOf('get_quest') === -1 && src.indexOf('l4m') === -1 && src.indexOf('link4m') === -1) continue;
            try {
                var cdoc = ifr.contentDocument || ifr.contentWindow.document;
                if (cdoc) {
                    var inner = cdoc.querySelectorAll('a, button, div, span');
                    for (var j = 0; j < inner.length; j++) {
                        var el = inner[j];
                        var t = (el.textContent || '').replace(/\s+/g, ' ').trim();
                        if (/lấy\s*mã/i.test(t) && t.length < 80) return { el: el, type: 'iframe-inner' };
                    }
                }
            } catch (e) { return { el: ifr, type: 'iframe-outer' }; }
        }
        return null;
    }

    function findL4MByPoint() {
        var w = window.innerWidth, h = window.innerHeight;
        var step = 60;
        for (var y = 40; y < h - 40; y += step) {
            for (var x = 20; x < w - 20; x += step) {
                try {
                    var els = document.elementsFromPoint(x, y);
                    for (var i = 0; i < els.length; i++) {
                        var el = els[i];
                        if (el.closest('#mp-root') || el.closest('#mp-fab')) continue;
                        var t = (el.textContent || '').replace(/\s+/g, ' ').trim();
                        if (t.length < 3 || t.length > 100) continue;
                        if (!/lấy\s*mã|lay\s*ma/i.test(t)) continue;
                        if (/test|debug|kiểm tra|reset|sao chép|bật lướt|tắt lướt|quét/i.test(t)) continue;
                        return el;
                    }
                } catch (e) {}
            }
        }
        return null;
    }

    function clickL4M(el, type) {
        try { el.scrollIntoView({ behavior: 'instant', block: 'center' }); } catch (e) {}
        setTimeout(function() {
            var r;
            try { r = el.getBoundingClientRect(); } catch (e) { r = null; }
            var cx = r ? r.left + r.width / 2 : 0;
            var cy = r ? r.top + r.height / 2 : 0;
            try { el.click(); } catch (e) {}
            try { el.dispatchEvent(new Event('click', { bubbles: true, cancelable: true })); } catch (e) {}
            try { el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, clientX: cx, clientY: cy })); } catch (e) {}
            try {
                el.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, clientX: cx, clientY: cy }));
                el.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true, clientX: cx, clientY: cy }));
                el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, clientX: cx, clientY: cy }));
            } catch (e) {}
            try {
                el.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, cancelable: true, clientX: cx, clientY: cy }));
                el.dispatchEvent(new PointerEvent('pointerup', { bubbles: true, cancelable: true, clientX: cx, clientY: cy }));
            } catch (e) {}
            try {
                el.dispatchEvent(new TouchEvent('touchstart', { bubbles: true, cancelable: true }));
                el.dispatchEvent(new TouchEvent('touchend', { bubbles: true, cancelable: true }));
            } catch (e) {}
            try {
                var child = el.querySelector('span, img, a, button, b, strong, i, em, div');
                if (child && child !== el) { child.click(); child.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true })); }
            } catch (e) {}
            try { if (el.parentElement && el.parentElement !== document.body) el.parentElement.click(); } catch (e) {}
            try {
                if (cx > 0 && cy > 0) {
                    var topEl = document.elementFromPoint(cx, cy);
                    if (topEl && !topEl.closest('#mp-root')) {
                        topEl.click();
                        topEl.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, clientX: cx, clientY: cy }));
                    }
                    var stack = document.elementsFromPoint(cx, cy);
                    for (var s = 0; s < stack.length && s < 5; s++) {
                        var se = stack[s];
                        if (se.closest('#mp-root') || se.closest('#mp-fab')) continue;
                        try { se.click(); } catch (e) {}
                    }
                }
            } catch (e) {}
            try { el.focus(); el.click(); } catch (e) {}
            if (type === 'iframe-outer') {
                try { el.click(); el.focus(); } catch (e) {}
                if (cx > 0 && cy > 0) {
                    try {
                        var topEl2 = document.elementFromPoint(cx, cy);
                        if (topEl2) {
                            topEl2.click();
                            topEl2.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, clientX: cx, clientY: cy }));
                        }
                    } catch (e) {}
                }
            }
            log('✓ Đã click nút L4M (' + (type || 'normal') + ')');
        }, 200);
    }

    function startAutoScroll() {
        if (scrollState.active) return;
        S.set('scrollOn', '1');
        if (UI.scrollToggleBtn) { UI.scrollToggleBtn.textContent = '🛑 TẮT LƯỚT'; UI.scrollToggleBtn.className = 'mp-btn red'; }
        scrollState.active = true;
        scrollState.originY = window.pageYOffset || document.documentElement.scrollTop || 0;
        scrollState.offset = 0;
        scrollState.dir = 1;
        scrollState.lastTime = performance.now();
        log('🔄 BẬT LƯỚT TẠI Y=' + Math.round(scrollState.originY));
        var step = function(now) {
            if (!scrollState.active) return;
            var dt = now - scrollState.lastTime;
            scrollState.lastTime = now;
            if (dt > 50) dt = 50;
            var move = scrollState.step * (dt / 16);
            scrollState.offset += scrollState.dir * move;
            if (scrollState.offset >= scrollState.maxOffset) { scrollState.offset = scrollState.maxOffset; scrollState.dir = -1; }
            else if (scrollState.offset <= -scrollState.maxOffset) { scrollState.offset = -scrollState.maxOffset; scrollState.dir = 1; }
            try { window.scrollTo(0, Math.round(scrollState.originY + scrollState.offset)); } catch (e) {}
            scrollRAF = requestAnimationFrame(step);
        };
        scrollRAF = requestAnimationFrame(step);
    }

    function stopAutoScroll() {
        scrollState.active = false;
        if (scrollRAF) { cancelAnimationFrame(scrollRAF); scrollRAF = null; }
        S.set('scrollOn', '0');
        if (UI.scrollToggleBtn) { UI.scrollToggleBtn.textContent = '🔄 BẬT LƯỚT'; UI.scrollToggleBtn.className = 'mp-btn orange'; }
        log('🛑 TẮT LƯỚT');
    }

    function renderDomainList() {
        if (!UI.domainList) return;
        var list = DOMAINS.getList();
        UI.domainList.innerHTML = '';
        if (!list.length) { UI.domainList.innerHTML = '<div class="mp-empty">Chưa có domain nào</div>'; return; }
        for (var i = 0; i < list.length; i++) {
            (function(item) {
                var row = document.createElement('div');
                row.className = 'mp-domain-item';
                var name = document.createElement('div');
                name.className = 'd-name'; name.textContent = item.d;
                var useBtn = document.createElement('button');
                useBtn.className = 'd-use'; useBtn.textContent = 'DÙNG';
                useBtn.onclick = function(e) {
                    e.stopPropagation();
                    var mode = getMode();
                    if (mode === 'url') UI.domainInput.value = item.d;
                    else UI.urlInputKw.value = 'https://' + item.d;
                };
                var delBtn = document.createElement('button');
                delBtn.className = 'd-del'; delBtn.textContent = '×';
                delBtn.onclick = function(e) { e.stopPropagation(); DOMAINS.remove(item.d); renderDomainList(); };
                row.appendChild(name); row.appendChild(useBtn); row.appendChild(delBtn);
                row.onclick = function() {
                    var mode = getMode();
                    if (mode === 'url') UI.domainInput.value = item.d;
                    else UI.urlInputKw.value = 'https://' + item.d;
                };
                UI.domainList.appendChild(row);
            })(list[i]);
        }
    }

    function toggleMin() {
        if (!UI.root) return;
        var m = UI.root.classList.toggle('mp-min');
        UI.minBtn.textContent = m ? '+' : '−';
        S.set('min', m ? '1' : '0');
    }

    function enableDrag() {
        var h = UI.head; if (!h) return;
        var dg = false, sx = 0, sy = 0, ox = 0, oy = 0;
        var dn = function(e) {
            if (e.target.closest('.mp-icon-btn')) return;
            if (UI.root.classList.contains('mp-min')) { toggleMin(); return; }
            dg = true;
            var p = e.touches ? e.touches[0] : e;
            sx = p.clientX; sy = p.clientY;
            var r = UI.root.getBoundingClientRect();
            ox = r.left; oy = r.top;
            UI.root.style.left = ox + 'px'; UI.root.style.top = oy + 'px'; UI.root.style.right = 'auto';
            document.addEventListener('mousemove', mv, { passive: false });
            document.addEventListener('mouseup', up);
            document.addEventListener('touchmove', mv, { passive: false });
            document.addEventListener('touchend', up);
            e.preventDefault();
        };
        var mv = function(e) {
            if (!dg) return;
            var p = e.touches ? e.touches[0] : e;
            var nx = ox + (p.clientX - sx), ny = oy + (p.clientY - sy);
            nx = Math.max(0, Math.min(nx, window.innerWidth - UI.root.offsetWidth));
            ny = Math.max(0, Math.min(ny, window.innerHeight - UI.root.offsetHeight));
            UI.root.style.left = nx + 'px'; UI.root.style.top = ny + 'px';
            if (e.cancelable) e.preventDefault();
        };
        var up = function() {
            if (!dg) return;
            dg = false;
            var r = UI.root.getBoundingClientRect();
            S.set('pos', { x: r.left, y: r.top });
            document.removeEventListener('mousemove', mv);
            document.removeEventListener('mouseup', up);
            document.removeEventListener('touchmove', mv);
            document.removeEventListener('touchend', up);
        };
        h.addEventListener('mousedown', dn);
        h.addEventListener('touchstart', dn, { passive: false });
    }

    function refreshStatus() {
        if (!UI.status) return;
        var map = {
            'idle': '🌈 Sẵn sàng',
            'click-google': '🖱️ Đang click Google...',
            'scan-click1': '🔎 Đang săn nút L4M...',
            'counting1': '⏳ Đếm phase 1...',
            'wait-reload-text': '👀 Chờ reload...',
            'reloading': '🔄 Đang reload...',
            'scan-click2': '🎯 Săn nút lần 2...',
            'counting2': '⏳ Đếm phase 2...',
            'got-code': '✅ Đã có mã',
            'back-link4m': '🏠 Về link4m...',
            'filling': '📝 Đã điền mã — giải captcha',
            'done': '🎉 HOÀN TẤT!'
        };
        UI.status.textContent = map[getState()] || getState();
    }

    function showTimer(sec, max, label) {
        if (!UI.timer) return;
        UI.timer.classList.add('show');
        UI.timerNum.textContent = sec;
        UI.timerCap.textContent = label || 'ĐANG CHỜ MÃ';
        if (max > 0) {
            var C_ = 2 * Math.PI * 26;
            var ratio = sec / max;
            if (ratio > 1) ratio = 1;
            if (ratio < 0) ratio = 0;
            UI.timerProg.style.strokeDashoffset = C_ * (1 - ratio);
        }
    }
    function hideTimer() { if (UI.timer) UI.timer.classList.remove('show'); }
    function showGuide(html) { if (UI.guide) { UI.guide.innerHTML = html; UI.guide.classList.add('show'); } }
    function showCode(code) {
        if (!UI.code) return;
        UI.code.classList.add('show');
        UI.codeVal.textContent = code;
        try { navigator.clipboard.writeText(code); log('📋 Đã copy code:', code); } catch (e) {}
    }

    var CD_PATTERNS = [
        /vui lòng chờ\s*(\d+)\s*s?\s*\(\s*(\d+)\s*\/\s*(\d+)\s*\)/i,
        /vui lòng chờ\s*(\d+)\s*giây\s*\(\s*(\d+)\s*\/\s*(\d+)\s*\)/i,
        /chờ\s*(\d+)\s*s\s*\(\s*(\d+)\s*\/\s*(\d+)\s*\)/i,
        /chờ\s*(\d+)\s*giây\s*\(\s*(\d+)\s*\/\s*(\d+)\s*\)/i,
        /(\d+)\s*s\s*\(\s*(\d+)\s*\/\s*(\d+)\s*\)/i,
        /vui lòng chờ\s*(\d+)\s*s\b/i,
        /vui lòng chờ\s*(\d+)\s*giây/i,
        /chờ\s*(\d+)\s*s\b/i,
        /chờ\s*(\d+)\s*giây/i,
        /còn[:\s]*(\d+)\s*giây/i,
        /còn[:\s]*(\d+)\s*s\b/i,
        /còn[:\s]*(\d+)/i
    ];

    function parseCountdownText(text) {
        if (!text) return null;
        var cleaned = text.replace(/lấy\s*mã\s*sau\s*\d+\s*s/gi, '');
        var best = null;
        for (var p = 0; p < CD_PATTERNS.length; p++) {
            var m = cleaned.match(CD_PATTERNS[p]);
            if (m) {
                var sec = parseInt(m[1], 10);
                var phase = m[2] ? parseInt(m[2], 10) : 1;
                var total = m[3] ? parseInt(m[3], 10) : 2;
                if (!isNaN(sec) && sec >= 0 && sec <= 999) {
                    if (m[2] && m[3]) return { sec: sec, phase: phase, total: total, raw: m[0] };
                    if (!best) best = { sec: sec, phase: phase, total: total, raw: m[0] };
                }
            }
        }
        return best;
    }

    function readCountdownInDoc(doc) {
        if (!doc) return null;
        try { var bt = (doc.body && doc.body.innerText) || ''; var r1 = parseCountdownText(bt); if (r1) return r1; } catch (e) {}
        try { var bc = (doc.body && doc.body.textContent) || ''; var r2 = parseCountdownText(bc); if (r2) return r2; } catch (e) {}
        try {
            var sels = ['#timer','#countdown','#clock','.timer','.countdown','.clock','[id*="timer" i]','[id*="count" i]','[id*="clock" i]','[id*="wait" i]','[class*="timer" i]','[class*="count" i]','[class*="clock" i]','[class*="wait" i]'];
            for (var s = 0; s < sels.length; s++) {
                var els = doc.querySelectorAll(sels[s]);
                for (var e = 0; e < els.length; e++) {
                    var el = els[e];
                    if (el.closest && el.closest('#mp-root')) continue;
                    var t = (el.textContent || '').trim();
                    var r3 = parseCountdownText(t);
                    if (r3) return r3;
                }
            }
        } catch (e) {}
        try {
            var walker = doc.createTreeWalker(doc.body || doc, NodeFilter.SHOW_TEXT, null, false);
            var node; var count = 0;
            while ((node = walker.nextNode()) && count < 5000) {
                count++;
                var text = (node.textContent || '').trim();
                if (!text || text.length < 3) continue;
                if (text.indexOf('chờ') === -1 && text.indexOf('còn') === -1 && text.indexOf('giây') === -1 && text.indexOf('s (') === -1 && text.indexOf('/') === -1) continue;
                var r4 = parseCountdownText(text);
                if (r4) return r4;
            }
        } catch (e) {}
        try {
            var iframes = doc.querySelectorAll('iframe');
            for (var f = 0; f < iframes.length; f++) {
                try { var cdoc = iframes[f].contentDocument || iframes[f].contentWindow.document; if (cdoc) { var r5 = readCountdownInDoc(cdoc); if (r5) return r5; } } catch (e) {}
            }
        } catch (e) {}
        try {
            var allEls = doc.querySelectorAll('*');
            for (var k = 0; k < allEls.length && k < 2000; k++) {
                var sr = allEls[k].shadowRoot;
                if (sr) { try { var r6 = readCountdownInDoc(sr); if (r6) return r6; } catch (e) {} }
            }
        } catch (e) {}
        return null;
    }

    function readServerCountdown() { return readCountdownInDoc(document); }

    function getFullTextAllDocs() {
        var all = '';
        try { all += (document.body.innerText || '') + ' '; } catch (e) {}
        try { all += (document.body.textContent || '') + ' '; } catch (e) {}
        try {
            var iframes = document.querySelectorAll('iframe');
            for (var i = 0; i < iframes.length; i++) {
                try {
                    var cdoc = iframes[i].contentDocument || iframes[i].contentWindow.document;
                    if (cdoc) {
                        all += (cdoc.body ? cdoc.body.innerText : '') + ' ';
                        all += (cdoc.body ? cdoc.body.textContent : '') + ' ';
                    }
                } catch (e) {}
            }
        } catch (e) {}
        return all;
    }

    function isAskClickLink() {
        var all = getFullTextAllDocs();
        var n = all.toLowerCase()
            .replace(/[àáạảãâầấậẩẫăằắặẳẵ]/g, 'a')
            .replace(/[èéẹẻẽêềếệểễ]/g, 'e')
            .replace(/[ìíịỉĩ]/g, 'i')
            .replace(/[òóọỏõôồốộổỗơờớợởỡ]/g, 'o')
            .replace(/[ùúụủũưừứựửữ]/g, 'u')
            .replace(/[ỳýỵỷỹ]/g, 'y')
            .replace(/[đ]/g, 'd')
            .replace(/\s+/g, ' ');
        if (/(nhan|click|bam).{0,30}(link|duong dan).{0,30}(bat ki|bat ky|bat cu)/i.test(n)) return true;
        if (/(vui long|hay).{0,30}(nhan|click|bam).{0,30}(link|duong dan)/i.test(n)) return true;
        if (/nhan vao link bat ki/i.test(n)) return true;
        if (/click vao link bat ki/i.test(n)) return true;
        if (/vui long nhan vao link/i.test(n)) return true;
        if (/vui long click vao link/i.test(n)) return true;
        if (/luot xuong vi tri nay/i.test(n)) return true;
        if (/vi tri nay de lay ma/i.test(n)) return true;
        if (/de lay ma/i.test(n) && /(nhan|click|luot)/i.test(n)) return true;
        if (/lay ma sau\s*\d+\s*s/i.test(n)) return true;
        if (/lay ma sau/i.test(n)) return true;
        return false;
    }

    function extractCode() {
        var all = getFullTextAllDocs();
        var patterns = [
            /mã\s*km[:\s]+([A-Za-z0-9_\-]{4,32})/i,
            /mã\s*code[:\s]+([A-Za-z0-9_\-]{4,32})/i,
            /mã\s*xác\s*nhận[:\s]+([A-Za-z0-9_\-]{4,32})/i,
            /mã\s*thưởng[:\s]+([A-Za-z0-9_\-]{4,32})/i
        ];
        for (var p = 0; p < patterns.length; p++) {
            var m = all.match(patterns[p]);
            if (m) {
                var c = m[1].trim();
                if (/^https?:\/\//i.test(c)) continue;
                if (/\.(com|net|org|me|vn|io|info)/i.test(c)) continue;
                if (c.length < 4 || c.length > 32) continue;
                return c;
            }
        }
        return null;
    }

    function findGoogleResult() {
        var mode = getMode();
        var domain = S.get('domain') || '';
        var kw = domain.toLowerCase().replace(/^https?:\/\//, '').replace(/^www\./, '').replace(/\/.*$/, '').trim();
        var kwMain = kw;
        var parts = kw.split('.');
        if (parts.length > 2) kwMain = parts[parts.length - 2] + '.' + parts[parts.length - 1];

        var allLinks = document.querySelectorAll('a[href^="http"]');
        var bestMatch = null, bestScore = -1;

        for (var i = 0; i < allLinks.length; i++) {
            var a = allLinks[i];
            var h = a.href.toLowerCase();
            if (/google\.|gstatic\.|googleusercontent\.|youtube\.|wikipedia\.|facebook\.|accounts\.|policies\.|support\.|maps\.|translate\./i.test(h)) continue;

            var score = 0;
            if (kw && h.indexOf(kw) !== -1) score += 100;
            else if (kwMain && h.indexOf(kwMain) !== -1) score += 80;
            try {
                var hostname = new URL(h).hostname.replace(/^www\./, '');
                if (hostname === kw) score += 120;
                else if (hostname === kwMain) score += 100;
                else if (hostname.indexOf(kwMain) !== -1) score += 60;
            } catch (e) {}

            if (a.closest('#search')) score += 20;
            if (a.closest('#rso')) score += 15;
            if (a.closest('.g')) score += 10;

            var rect = a.getBoundingClientRect();
            if (rect.top > 0 && rect.top < 800) score += 15;
            if (rect.top > 0 && rect.top < 400) score += 10;

            if (score > bestScore) { bestScore = score; bestMatch = a; }
        }

        if (bestMatch && bestScore >= 50) {
            log('✓ [' + mode + '] Link (score=' + bestScore + '):', bestMatch.href);
            return bestMatch;
        }

        var selectors = ['#search a[href^="http"]', '#rso a[href^="http"]', '.g a[href^="http"]'];
        for (var s = 0; s < selectors.length; s++) {
            var els = document.querySelectorAll(selectors[s]);
            for (var e = 0; e < els.length; e++) {
                var el = els[e];
                var href = el.href.toLowerCase();
                if (/google\.|gstatic\.|googleusercontent\.|youtube\.|wikipedia\.|facebook\.|accounts\.|policies\.|support\.|maps\.|translate\./i.test(href)) continue;
                if (href.indexOf('http') !== 0) continue;
                if (href.length < 15) continue;
                log('→ [' + mode + '] Fallback:', href);
                return el;
            }
        }
        return null;
    }

    function findContinueBtn() {
        var els = Array.prototype.slice.call(document.querySelectorAll('a, button'));
        for (var i = 0; i < els.length; i++) {
            var e = els[i];
            if (e.offsetParent === null || e.closest('#mp-root')) continue;
            if (/click vào đây|tiếp tục|continue/i.test((e.textContent || '').trim())) return e;
        }
        return null;
    }

    function findCodeInputOnLink4m() {
        var sels = ['input[name="code"]','input#code','input[placeholder*="Nhập mã"]','input[placeholder*="nhập mã"]','input[placeholder*="mã"]','input[placeholder*="code"]','input[type="text"]'];
        for (var i = 0; i < sels.length; i++) {
            var els = document.querySelectorAll(sels[i]);
            for (var j = 0; j < els.length; j++) {
                var el = els[j];
                if (el.closest('#mp-root')) continue;
                if (el.offsetParent === null) continue;
                if (el.name && /search|q|query/i.test(el.name)) continue;
                return el;
            }
        }
        return null;
    }

    function handleGoogle() {
        var st = getState();
        if (st !== 'click-google') return Promise.resolve();
        var mode = getMode();
        var kw = S.get('keyword');
        var domain = S.get('domain');
        log('🖱️ [' + mode + '] Click Google | kw=' + (kw || '') + ' | domain=' + domain);

        return sleep(30).then(function() {
            var i = 0;
            var check = function() {
                if (i >= 200) {
                    if (domain) {
                        S.set('targetUrl', 'https://' + domain);
                        setState('scan-click1');
                        window.open('https://' + domain, '_blank');
                    }
                    return Promise.resolve();
                }
                var link = findGoogleResult();
                if (link) {
                    log('✓ CLICK:', link.href);
                    S.set('targetUrl', link.href);
                    try { link.click(); } catch (e) {}
                    try { link.dispatchEvent(new Event('click', { bubbles: true, cancelable: true })); } catch (e) {}
                    try { link.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true })); } catch (e) {}
                    try { var child = link.querySelector('*'); if (child) child.click(); } catch (e) {}
                    setTimeout(function() { setState('scan-click1'); }, 150);
                    return Promise.resolve();
                }
                i++;
                return sleep(20).then(check);
            };
            return check();
        });
    }

    function handleLink4m() {
        var st = getState();
        var code = S.get('code');
        if (code) {
            var filled = S.get('filled', '0') === '1';
            var inp = findCodeInputOnLink4m();
            if (inp && !filled) {
                log('📝 ĐIỀN MÃ:', code);
                try {
                    inp.focus(); inp.value = code;
                    inp.dispatchEvent(new Event('input', { bubbles: true, cancelable: true }));
                    inp.dispatchEvent(new Event('change', { bubbles: true, cancelable: true }));
                    inp.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true }));
                    inp.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
                    inp.blur();
                    S.set('filled', '1');
                    showCode(code);
                    showGuide('<b>🌈 ĐÃ ĐIỀN MÃ 🌈</b><br>Mã: <b>' + code + '</b><br>1. Giải captcha<br>2. Nhấn "Click vào đây để tiếp tục"');
                    setState('filling');
                } catch (e) {}
            } else if (inp && filled) {
                showCode(code);
            }
        }
        if (st === 'idle') {
            UI.status.textContent = '🌈 Sẵn sàng';
            return Promise.resolve();
        }
        return Promise.resolve();
    }

    function handleTarget() {
        var st = getState();
        if (isRealTargetPage() && st === 'click-google') { setState('scan-click1'); return Promise.resolve(); }
        if (st === 'scan-click1' || st === 'scan-click2') {
            var btnEl = findL4MFast();
            var btnType = 'normal';
            if (!btnEl) { var ifr = findL4MInIframe(); if (ifr) { btnEl = ifr.el; btnType = ifr.type; } }
            if (!btnEl) { btnEl = findL4MByPoint(); if (btnEl) btnType = 'point'; }
            if (btnEl) {
                var lastClick = parseInt(S.get('lastClickTime', '0'), 10);
                if (Date.now() - lastClick < 2500) return Promise.resolve();
                log('✓✓✓ TÌM THẤY NÚT! CLICK.');
                UI.status.textContent = '✓ Đang click...';
                S.set('lastClickTime', Date.now().toString());
                clickL4M(btnEl, btnType);
                return sleep(2000).then(function() {
                    var sc = readServerCountdown();
                    if (sc) { S.set('lastServerSec', sc.sec.toString()); setState(st === 'scan-click1' ? 'counting1' : 'counting2'); }
                    else setState(st === 'scan-click1' ? 'counting1' : 'counting2');
                });
            }
            var sc0 = readServerCountdown();
            if (sc0) setState(st === 'scan-click1' ? 'counting1' : 'counting2');
            return Promise.resolve();
        }
        if (st === 'counting1') {
            var liveCode = extractCode();
            if (liveCode) { S.set('code', liveCode); showCode(liveCode); setState('got-code'); return Promise.resolve(); }
            var sc = readServerCountdown();
            if (!sc) {
                if (isAskClickLink()) { hideTimer(); S.set('waitReloadStart', Date.now().toString()); setState('wait-reload-text'); return Promise.resolve(); }
                var btn2 = findL4MFast() || (findL4MInIframe() ? findL4MInIframe().el : null) || findL4MByPoint();
                if (btn2) {
                    var lc = parseInt(S.get('lastClickTime', '0'), 10);
                    if (Date.now() - lc > 2500) { S.set('lastClickTime', Date.now().toString()); clickL4M(btn2, 'normal'); }
                }
                return Promise.resolve();
            }
            var totalSec = parseInt(S.get('serverTotalSec', '0'), 10);
            if (sc.sec > totalSec) { totalSec = sc.sec; S.set('serverTotalSec', totalSec.toString()); }
            if (totalSec === 0) { totalSec = sc.sec; S.set('serverTotalSec', totalSec.toString()); }
            showTimer(sc.sec, totalSec, 'CHỜ ' + sc.sec + ' GIÂY (' + sc.phase + '/' + sc.total + ')');
            S.set('lastServerSec', sc.sec.toString());
            if (sc.sec === 0) { S.del('serverTotalSec'); S.set('waitReloadStart', Date.now().toString()); setState('wait-reload-text'); }
            return Promise.resolve();
        }
        if (st === 'wait-reload-text') {
            var liveCode2 = extractCode();
            if (liveCode2) { S.set('code', liveCode2); showCode(liveCode2); setState('got-code'); return Promise.resolve(); }
            var waitStart = parseInt(S.get('waitReloadStart', '0'), 10);
            var elapsed = waitStart > 0 ? Date.now() - waitStart : 0;
            var askClick = isAskClickLink();
            var timeout = elapsed > 3000;
            var sc2 = readServerCountdown();
            if (sc2 && sc2.sec > 0 && !askClick && !timeout) { S.del('waitReloadStart'); setState('counting1'); return Promise.resolve(); }
            if (askClick || timeout) {
                showGuide('<b>🔄 ĐANG RELOAD...</b>');
                S.del('waitReloadStart');
                return sleep(800).then(function() { hideTimer(); setState('reloading'); location.reload(); });
            }
            return Promise.resolve();
        }
        if (st === 'reloading') { setState('scan-click2'); return sleep(1000); }
        if (st === 'counting2') {
            var liveCode3 = extractCode();
            if (liveCode3) { S.set('code', liveCode3); showCode(liveCode3); setState('got-code'); return Promise.resolve(); }
            var sc4 = readServerCountdown();
            if (!sc4) {
                var btn3 = findL4MFast() || (findL4MInIframe() ? findL4MInIframe().el : null) || findL4MByPoint();
                if (btn3) {
                    var lc3 = parseInt(S.get('lastClickTime', '0'), 10);
                    if (Date.now() - lc3 > 2500) { S.set('lastClickTime', Date.now().toString()); clickL4M(btn3, 'normal'); return Promise.resolve(); }
                }
                return Promise.resolve();
            }
            var totalSec2 = parseInt(S.get('serverTotalSec2', '0'), 10);
            if (sc4.sec > totalSec2) { totalSec2 = sc4.sec; S.set('serverTotalSec2', totalSec2.toString()); }
            if (totalSec2 === 0) { totalSec2 = (sc4.sec >= 30) ? sc4.sec : 60; S.set('serverTotalSec2', totalSec2.toString()); }
            showTimer(sc4.sec, totalSec2, 'CHỜ ' + sc4.sec + ' GIÂY (' + sc4.phase + '/' + sc4.total + ')');
            S.set('lastServerSec', sc4.sec.toString());
            if (sc4.sec === 0) {
                S.del('serverTotalSec2');
                var btn4 = findL4MFast() || (findL4MInIframe() ? findL4MInIframe().el : null) || findL4MByPoint();
                if (btn4) { S.set('lastClickTime', Date.now().toString()); clickL4M(btn4, 'normal'); }
            }
            return Promise.resolve();
        }
        if (st === 'got-code' || st === 'back-link4m') {
            setState('back-link4m');
            showGuide('<b>🏠 ĐANG VỀ LINK4M...</b>');
            var l4 = S.get('link4m');
            if (l4) return sleep(2000).then(function() { location.href = l4; });
            return Promise.resolve();
        }
        return Promise.resolve();
    }

    function loop() {
        if (loopRunning) return;
        loopRunning = true;
        log('▶ Vòng lặp (poll=' + CFG.poll + 'ms)');
        var i = 0;
        var tick = function() {
            if (i >= CFG.maxLoops) { loopRunning = false; return; }
            i++;
            var p;
            if (isGoogle) p = handleGoogle();
            else if (isRealTargetPage()) p = handleTarget();
            else if (isLink4m) p = handleLink4m();
            else p = Promise.resolve();
            p.catch(function(e){ log('Lỗi:', e.message); }).then(function() {
                if (getState() === 'done') { loopRunning = false; return; }
                setTimeout(tick, CFG.poll);
            });
        };
        tick();
    }

    function boot() {
        buildPanel();
        var st = getState();
        log('Khởi động | Host:', HOST, '| State:', st, '| Mode:', getMode());
        refreshStatus();

        if (S.get('code')) showCode(S.get('code'));
        if (isRealTargetPage() && st === 'click-google') setState('scan-click1');
        if (st && st !== 'idle' && st !== 'done') loop();
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
    else boot();
})();