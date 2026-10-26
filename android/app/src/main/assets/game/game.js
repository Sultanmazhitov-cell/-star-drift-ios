const $ = (id) => document.getElementById(id);
const canvas = $('gameCanvas');
const ctx = canvas.getContext('2d');
const overlay = $('gameOverlay');
const startButton = $('startButton');
const pauseButton = $('pauseButton');
const soundButton = $('soundButton');
const restartButton = $('restartButton');
const TAU = Math.PI * 2;
const keys = new Set();
const random = (a, b) => a + Math.random() * (b - a);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
let width = 800, height = 520, dpr = 1, lastTime = 0, visualTime = 0;
let status = 'ready', elapsed = 0, score = 0, starScore = 0, lives = 3;
let best = 0, asteroidTimer = 0.7, starTimer = 1.2, shake = 0;
let asteroids = [], stars = [], particles = [], trails = [];
let pointer = null, audio = null, soundEnabled = false;
let ship = { x: 400, y: 425, invulnerable: 0, lean: 0 };
try { best = Math.max(0, Number(localStorage.getItem('star-drift-best')) || 0); } catch {}

const backgroundStars = Array.from({ length: 105 }, () => ({
  x: Math.random(), y: Math.random(), radius: random(0.5, 1.7), speed: random(6, 25), phase: random(0, TAU),
}));

function resize() {
  const bounds = canvas.getBoundingClientRect();
  const oldWidth = width, oldHeight = height;
  width = Math.max(240, bounds.width || 800);
  height = Math.max(260, bounds.height || 520);
  dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.round(width * dpr);
  canvas.height = Math.round(height * dpr);
  ship.x = clamp(ship.x / oldWidth * width, 22, width - 22);
  ship.y = clamp(ship.y / oldHeight * height, 24, height - 26);
  for (const item of [...asteroids, ...stars, ...particles, ...trails]) {
    item.x = item.x / oldWidth * width;
    item.y = item.y / oldHeight * height;
  }
  pointer = null;
}

function updateHUD() {
  const text = (id, value) => { if ($(id).textContent !== value) $(id).textContent = value; };
  text('scoreValue', String(Math.floor(score)).padStart(4, '0'));
  text('bestValue', String(best).padStart(4, '0'));
  const hearts = Array.from({ length: 3 }, (_, index) => index < lives ? '♥' : '♡').join(' ');
  if ($('livesValue').textContent !== hearts) {
    $('livesValue').textContent = hearts;
    $('livesValue').setAttribute('aria-label', `Осталось щитов: ${lives}`);
  }
  const seconds = Math.floor(elapsed);
  text('timeValue', `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`);
}

function showOverlay(eyebrow, title, description, action) {
  $('overlayEyebrow').textContent = eyebrow;
  $('overlayTitle').textContent = title;
  $('overlayDescription').textContent = description;
  startButton.textContent = action;
  overlay.hidden = false;
  overlay.setAttribute('aria-hidden', 'false');
}

function hideOverlay() {
  overlay.hidden = true;
  overlay.setAttribute('aria-hidden', 'true');
}

function reset() {
  elapsed = 0; score = 0; starScore = 0; lives = 3;
  asteroids = []; stars = []; particles = []; trails = [];
  asteroidTimer = 0.65; starTimer = 1.0; shake = 0; pointer = null;
  ship = { x: width / 2, y: height * 0.8, invulnerable: 0.8, lean: 0 };
  keys.clear();
  updateHUD();
}

function start() {
  if (status === 'paused') { resume(); return; }
  reset();
  status = 'playing';
  hideOverlay();
  pauseButton.disabled = false;
  pauseButton.setAttribute('aria-label', 'Приостановить игру');
  pauseButton.setAttribute('aria-pressed', 'false');
  pauseButton.innerHTML = '<svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><rect x="5" y="4" width="3" height="12" rx="1"/><rect x="12" y="4" width="3" height="12" rx="1"/></svg>';
  canvas.focus({ preventScroll: true });
  playSound('start');
}

function pause() {
  if (status !== 'playing') return;
  status = 'paused'; keys.clear(); pointer = null;
  pauseButton.setAttribute('aria-label', 'Продолжить игру');
  pauseButton.setAttribute('aria-pressed', 'true');
  pauseButton.innerHTML = '<svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="m6 3 11 7-11 7V3Z"/></svg>';
  showOverlay('НЕБОЛЬШАЯ ПЕРЕДЫШКА', 'Полёт на паузе', 'Космос подождёт. Продолжите, когда будете готовы.', 'Продолжить полёт');
}

function resume() {
  if (status !== 'paused') return;
  status = 'playing';
  hideOverlay();
  pauseButton.setAttribute('aria-label', 'Приостановить игру');
  pauseButton.setAttribute('aria-pressed', 'false');
  pauseButton.innerHTML = '<svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><rect x="5" y="4" width="3" height="12" rx="1"/><rect x="12" y="4" width="3" height="12" rx="1"/></svg>';
  canvas.focus({ preventScroll: true });
  if (soundEnabled && audio?.state === 'suspended') audio.resume().catch(() => {});
}

function gameOver() {
  status = 'over';
  pointer = null; keys.clear();
  const total = Math.floor(score);
  const record = total > best;
  if (record) {
    best = total;
    try { localStorage.setItem('star-drift-best', String(best)); } catch {}
  }
  updateHUD();
  pauseButton.disabled = true;
  showOverlay(record ? 'НОВЫЙ ЛИЧНЫЙ РЕКОРД' : 'ПОЛЁТ ЗАВЕРШЁН', record ? 'Вот это полёт!' : 'Ещё один рейс?', `Вы набрали ${total} очк. и продержались ${Math.floor(elapsed)} сек. Звёзды снова ждут вас.`, 'Играть снова');
  playSound('over');
}

function initializeAudio() {
  if (!audio) {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return false;
    try { audio = new AudioContext(); } catch { return false; }
  }
  if (audio.state === 'suspended') audio.resume().catch(() => {});
  return true;
}

function tone(frequency, duration, type = 'sine', delay = 0, volume = 0.035) {
  if (!soundEnabled || !audio) return;
  try {
    const oscillator = audio.createOscillator(), gain = audio.createGain();
    const time = audio.currentTime + delay;
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, time);
    gain.gain.setValueAtTime(volume, time);
    gain.gain.exponentialRampToValueAtTime(0.0001, time + duration);
    oscillator.connect(gain); gain.connect(audio.destination);
    oscillator.start(time); oscillator.stop(time + duration);
  } catch {}
}

function playSound(kind) {
  if (kind === 'star') { tone(780, 0.12); tone(1170, 0.17, 'sine', 0.07); }
  if (kind === 'hit') { tone(110, 0.22, 'triangle', 0, 0.07); tone(65, 0.25, 'sawtooth', 0.04, 0.025); }
  if (kind === 'start') { tone(440, 0.13); tone(660, 0.18, 'sine', 0.1); }
  if (kind === 'over') { tone(330, 0.2); tone(220, 0.28, 'triangle', 0.12); tone(165, 0.3, 'sine', 0.26); }
}

function spawnAsteroid() {
  const radius = random(14, width < 500 ? 27 : 35);
  const points = Array.from({ length: 9 }, () => random(0.7, 1.15));
  asteroids.push({
    x: random(radius + 6, width - radius - 6), y: -radius * 2,
    radius, speed: random(90, 140) + Math.min(elapsed * 1.8, 140),
    drift: random(-17, 17), rotation: random(0, TAU), spin: random(-0.65, 0.65), points,
  });
}

function spawnStar() {
  stars.push({ x: random(28, width - 28), y: -24, radius: 10, speed: random(75, 108), phase: random(0, TAU) });
}

function burst(x, y, color, count = 16) {
  for (let i = 0; i < count; i++) {
    const angle = random(0, TAU), speed = random(35, 155);
    particles.push({ x, y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, life: random(0.3, 0.7), maxLife: 0.7, color, size: random(1.5, 3.5) });
  }
}

function update(dt) {
  if (status !== 'playing') return;
  elapsed += dt;
  score = Math.floor(elapsed * 8) + starScore;
  ship.invulnerable = Math.max(0, ship.invulnerable - dt);
  shake = Math.max(0, shake - dt * 28);
  let dx = Number(keys.has('arrowright') || keys.has('d')) - Number(keys.has('arrowleft') || keys.has('a'));
  let dy = Number(keys.has('arrowdown') || keys.has('s')) - Number(keys.has('arrowup') || keys.has('w'));
  const previousX = ship.x;
  if (dx || dy) {
    const length = Math.hypot(dx, dy);
    ship.x += dx / length * 310 * dt;
    ship.y += dy / length * 310 * dt;
    pointer = null;
  } else if (pointer) {
    const distance = Math.hypot(pointer.targetX - ship.x, pointer.targetY - ship.y);
    const step = Math.min(distance, 580 * dt);
    if (distance > 0) {
      ship.x += (pointer.targetX - ship.x) / distance * step;
      ship.y += (pointer.targetY - ship.y) / distance * step;
    }
  }
  ship.x = clamp(ship.x, 22, width - 22);
  ship.y = clamp(ship.y, 30, height - 28);
  ship.lean += (clamp((ship.x - previousX) / Math.max(dt, 0.001) / 700, -0.3, 0.3) - ship.lean) * Math.min(1, dt * 12);
  trails.push({ x: ship.x + random(-3, 3), y: ship.y + 17, life: 0.35, maxLife: 0.35 });
  asteroidTimer -= dt;
  if (asteroidTimer <= 0) {
    spawnAsteroid();
    asteroidTimer = Math.max(0.29, 0.9 - elapsed * 0.006) * random(0.8, 1.2);
  }
  starTimer -= dt;
  if (starTimer <= 0) { spawnStar(); starTimer = random(1.1, 1.9); }
  for (const asteroid of asteroids) {
    asteroid.y += asteroid.speed * dt;
    asteroid.x += asteroid.drift * dt;
    asteroid.rotation += asteroid.spin * dt;
    if (!asteroid.hit && ship.invulnerable <= 0 && Math.hypot(asteroid.x - ship.x, asteroid.y - ship.y) < asteroid.radius * 0.78 + 10) {
      asteroid.hit = true;
      lives--;
      ship.invulnerable = 1.65;
      shake = 7;
      burst(ship.x, ship.y, '#ff9b6b', 22);
      burst(asteroid.x, asteroid.y, '#8d7c73', 12);
      playSound('hit');
      if (lives <= 0) { gameOver(); break; }
    }
  }
  if (status === 'playing') {
    for (const star of stars) {
      star.y += star.speed * dt;
      star.phase += dt * 2;
      if (!star.collected && Math.hypot(star.x - ship.x, star.y - ship.y) < 25) {
        star.collected = true;
        starScore += 50;
        score = Math.floor(elapsed * 8) + starScore;
        burst(star.x, star.y, '#fbd18b', 14);
        playSound('star');
      }
    }
  }
  asteroids = asteroids.filter(a => !a.hit && a.y < height + a.radius * 2);
  stars = stars.filter(s => !s.collected && s.y < height + 25);
  updateHUD();
}

function updateEffects(dt) {
  if (status === 'paused') return;
  for (const p of particles) { p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt; }
  particles = particles.filter(p => p.life > 0);
  for (const t of trails) { t.life -= dt; t.y += 35 * dt; }
  trails = trails.filter(t => t.life > 0);
}

function drawBackground() {
  ctx.fillStyle = '#080f1b'; ctx.fillRect(0, 0, width, height);
  const nebula = ctx.createRadialGradient(width * 0.62, height * 0.25, 0, width * 0.62, height * 0.25, width * 0.7);
  nebula.addColorStop(0, 'rgba(39, 96, 114, 0.12)');
  nebula.addColorStop(0.5, 'rgba(25, 55, 77, 0.06)');
  nebula.addColorStop(1, 'rgba(8, 15, 27, 0)');
  ctx.fillStyle = nebula; ctx.fillRect(0, 0, width, height);
  ctx.lineWidth = 1;
  ctx.strokeStyle = 'rgba(116,163,181,0.035)';
  for (let x = width % 64; x < width; x += 64) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke(); }
  for (let y = height % 64; y < height; y += 64) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke(); }
  for (const s of backgroundStars) {
    const y = (s.y * height + visualTime * s.speed) % (height + 10) - 5;
    ctx.globalAlpha = 0.25 + (Math.sin(visualTime * 0.7 + s.phase) + 1) * 0.19;
    ctx.fillStyle = '#d5e6ef';
    ctx.beginPath(); ctx.arc(s.x * width, y, s.radius, 0, TAU); ctx.fill();
  }
  ctx.globalAlpha = 1;
  // A quiet orbital arc gives the field depth without obscuring hazards.
  ctx.strokeStyle = 'rgba(101, 167, 185, 0.08)';
  ctx.beginPath(); ctx.ellipse(width * 0.5, height * 0.2, width * 0.58, height * 0.68, -0.3, 0, TAU); ctx.stroke();
}

function drawAsteroid(a) {
  ctx.save(); ctx.translate(a.x, a.y); ctx.rotate(a.rotation);
  ctx.beginPath();
  a.points.forEach((r, i) => {
    const angle = i / a.points.length * TAU;
    const x = Math.cos(angle) * a.radius * r, y = Math.sin(angle) * a.radius * r;
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  });
  ctx.closePath();
  const gradient = ctx.createLinearGradient(-a.radius, -a.radius, a.radius, a.radius);
  gradient.addColorStop(0, '#6b6264'); gradient.addColorStop(0.45, '#3b3b46'); gradient.addColorStop(1, '#202631');
  ctx.fillStyle = gradient; ctx.fill();
  ctx.strokeStyle = '#8e7976'; ctx.lineWidth = 1.3; ctx.stroke();
  ctx.fillStyle = 'rgba(10, 16, 25, 0.35)';
  ctx.beginPath(); ctx.ellipse(-a.radius * 0.21, -a.radius * 0.19, a.radius * 0.22, a.radius * 0.16, -0.4, 0, TAU); ctx.fill();
  ctx.beginPath(); ctx.arc(a.radius * 0.32, a.radius * 0.3, a.radius * 0.12, 0, TAU); ctx.fill();
  ctx.restore();
}

function drawStar(s) {
  ctx.save(); ctx.translate(s.x, s.y); ctx.rotate(s.phase * 0.35);
  ctx.shadowColor = '#f5c27e'; ctx.shadowBlur = 16;
  ctx.fillStyle = '#fbd18b';
  ctx.beginPath();
  for (let i = 0; i < 8; i++) {
    const angle = i / 8 * TAU - Math.PI / 2;
    const radius = i % 2 === 0 ? 10 : 3.7;
    if (i === 0) ctx.moveTo(Math.cos(angle) * radius, Math.sin(angle) * radius);
    else ctx.lineTo(Math.cos(angle) * radius, Math.sin(angle) * radius);
  }
  ctx.closePath(); ctx.fill(); ctx.shadowBlur = 0;
  ctx.strokeStyle = 'rgba(251,209,139,0.22)';
  ctx.beginPath(); ctx.arc(0, 0, 17 + Math.sin(s.phase) * 2, 0, TAU); ctx.stroke();
  ctx.restore();
}

function drawShip() {
  if (status === 'over' || status === 'ready') return;
  ctx.save();
  ctx.translate(ship.x, ship.y); ctx.rotate(ship.lean);
  if (ship.invulnerable > 0 && status === 'playing') {
    ctx.strokeStyle = `rgba(140,226,224,${0.16 + Math.sin(visualTime * 15) * 0.1})`;
    ctx.fillStyle = 'rgba(140,226,224,0.035)';
    ctx.beginPath(); ctx.arc(0, 0, 28, 0, TAU); ctx.fill(); ctx.stroke();
  }
  ctx.globalAlpha = ship.invulnerable > 0 && status === 'playing' ? 0.6 + Math.sin(visualTime * 30) * 0.3 : 1;
  if (status === 'playing' || status === 'ready') {
    const flame = 12 + Math.sin(visualTime * 35) * 4;
    const glow = ctx.createLinearGradient(0, 12, 0, 12 + flame);
    glow.addColorStop(0, '#c3fcf1'); glow.addColorStop(0.35, '#6fd7d3'); glow.addColorStop(1, 'rgba(92,211,215,0)');
    ctx.fillStyle = glow;
    ctx.beginPath(); ctx.moveTo(-4, 12); ctx.lineTo(0, 15 + flame); ctx.lineTo(4, 12); ctx.closePath(); ctx.fill();
  }
  ctx.shadowColor = 'rgba(98,215,214,0.4)'; ctx.shadowBlur = 14;
  ctx.fillStyle = '#cadbdd'; ctx.strokeStyle = '#f4fcf8'; ctx.lineWidth = 0.8;
  ctx.beginPath(); ctx.moveTo(0, -21); ctx.lineTo(8, -1); ctx.lineTo(18, 14); ctx.lineTo(6, 10); ctx.lineTo(0, 15); ctx.lineTo(-6, 10); ctx.lineTo(-18, 14); ctx.lineTo(-8, -1); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.shadowBlur = 0;
  ctx.fillStyle = '#619aaf';
  ctx.beginPath(); ctx.moveTo(0, -11); ctx.lineTo(4, 2); ctx.lineTo(0, 6); ctx.lineTo(-4, 2); ctx.closePath(); ctx.fill();
  ctx.strokeStyle = '#7edbd6';
  ctx.beginPath(); ctx.moveTo(-12, 10); ctx.lineTo(-5, 6); ctx.moveTo(12, 10); ctx.lineTo(5, 6); ctx.stroke();
  ctx.restore();
}

function draw() {
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  drawBackground();
  ctx.save();
  if (shake > 0 && status === 'playing') ctx.translate(random(-shake, shake), random(-shake, shake));
  for (const t of trails) {
    ctx.fillStyle = `rgba(117,221,218,${t.life / t.maxLife * 0.25})`;
    ctx.beginPath(); ctx.arc(t.x, t.y, 1.5 * t.life / t.maxLife, 0, TAU); ctx.fill();
  }
  asteroids.forEach(drawAsteroid);
  stars.forEach(drawStar);
  for (const p of particles) {
    ctx.globalAlpha = p.life / p.maxLife;
    ctx.fillStyle = p.color;
    ctx.beginPath(); ctx.arc(p.x, p.y, p.size * p.life / p.maxLife, 0, TAU); ctx.fill();
  }
  ctx.globalAlpha = 1;
  drawShip();
  ctx.restore();
}

function frame(timestamp) {
  const dt = Math.min((timestamp - (lastTime || timestamp)) / 1000, 0.04);
  lastTime = timestamp;
  if (status !== 'paused') visualTime += dt;
  update(dt); updateEffects(dt); draw();
  requestAnimationFrame(frame);
}

startButton.addEventListener('click', start);
pauseButton.addEventListener('click', () => status === 'paused' ? resume() : pause());
restartButton?.addEventListener('click', () => { status = 'ready'; start(); });
soundButton.addEventListener('click', () => {
  if (!soundEnabled && !initializeAudio()) {
    soundButton.setAttribute('aria-label', 'Звук недоступен в этом браузере');
    return;
  }
  soundEnabled = !soundEnabled;
  soundButton.setAttribute('aria-pressed', String(soundEnabled));
  soundButton.setAttribute('aria-label', soundEnabled ? 'Выключить звук' : 'Включить звук');
  soundButton.dataset.enabled = String(soundEnabled);
  soundButton.innerHTML = `<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><path d="M9 4 5 7H2v6h3l4 3V4Z"/>${soundEnabled ? '<path d="M12 6a5 5 0 0 1 0 8m3-11a9 9 0 0 1 0 14"/>' : '<path d="m13 7 5 6m0-6-5 6"/>'}</svg>`;
  soundButton.title = soundEnabled ? 'Выключить звук' : 'Включить звук';
  if (soundEnabled) playSound('star');
});

const controlKeys = ['arrowleft', 'arrowright', 'arrowup', 'arrowdown', 'w', 'a', 's', 'd'];
window.addEventListener('keydown', (event) => {
  if (event.target instanceof HTMLElement && ['INPUT', 'TEXTAREA', 'SELECT'].includes(event.target.tagName)) return;
  const key = ({KeyW:'w',KeyA:'a',KeyS:'s',KeyD:'d',KeyP:'p'})[event.code] || event.key.toLowerCase();
  if (controlKeys.includes(key)) {
    if (status === 'playing') { event.preventDefault(); keys.add(key); }
    return;
  }
  const focusedControl = ['BUTTON', 'A'].includes(event.target?.tagName);
  if ((key === 'escape' || key === 'p' || (key === ' ' && !focusedControl)) && !event.repeat) {
    if (status === 'playing' || status === 'paused') {
      event.preventDefault();
      status === 'playing' ? pause() : resume();
    } else if (key === ' ') {
      event.preventDefault(); start();
    }
  }
  if (key === 'enter' && !event.repeat && !['BUTTON', 'A'].includes(event.target?.tagName) && status !== 'playing') {
    event.preventDefault(); start();
  }
});
window.addEventListener('keyup', (event) => keys.delete(({KeyW:'w',KeyA:'a',KeyS:'s',KeyD:'d'})[event.code] || event.key.toLowerCase()));
window.addEventListener('blur', pause);
document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); });
canvas.addEventListener('pointerdown', (event) => {
  if (status !== 'playing' || pointer || (event.pointerType === 'mouse' && event.button !== 0)) return;
  event.preventDefault();
  canvas.setPointerCapture?.(event.pointerId);
  const rect = canvas.getBoundingClientRect();
  // Anchor each new gesture to the ship, so touching elsewhere never moves it.
  pointer = {
    id: event.pointerId,
    x: (event.clientX - rect.left) / rect.width * width,
    y: (event.clientY - rect.top) / rect.height * height,
    targetX: ship.x, targetY: ship.y,
  };
  canvas.focus({ preventScroll: true });
});
canvas.addEventListener('pointermove', (event) => {
  if (!pointer || event.pointerId !== pointer.id || status !== 'playing') return;
  event.preventDefault();
  const rect = canvas.getBoundingClientRect();
  const x = (event.clientX - rect.left) / rect.width * width;
  const y = (event.clientY - rect.top) / rect.height * height;
  // Clamp the target every move so reversing at an edge responds immediately.
  pointer.targetX = clamp(pointer.targetX + x - pointer.x, 22, width - 22);
  pointer.targetY = clamp(pointer.targetY + y - pointer.y, 30, height - 28);
  pointer.x = x; pointer.y = y;
});
const endPointer = (event) => { if (pointer?.id === event.pointerId) pointer = null; };
canvas.addEventListener('pointerup', endPointer);
canvas.addEventListener('pointercancel', endPointer);
canvas.addEventListener('lostpointercapture', endPointer);
canvas.style.touchAction = 'none';
canvas.setAttribute('tabindex', '0');
canvas.setAttribute('aria-label', 'Игровое поле. Управляйте кораблём стрелками, WASD или движением пальца в любом месте поля. Корабль повторяет движения пальца. Пробел — пауза.');
pauseButton.disabled = true;
soundButton.setAttribute('aria-pressed', 'false');
soundButton.setAttribute('aria-label', 'Включить звук');
if (typeof ResizeObserver !== 'undefined') new ResizeObserver(resize).observe(canvas);
window.addEventListener('resize', resize);
resize(); updateHUD();
// A light demo composition makes the field inviting before the first flight.
asteroids = [
  { x: width * 0.16, y: height * 0.27, radius: 25, rotation: 0.3, points: [0.9, 1.1, 0.8, 1, 0.9, 1.1, 0.8, 1, 0.9] },
  { x: width * 0.84, y: height * 0.64, radius: 33, rotation: 0.8, points: [0.9, 0.8, 1.1, 1, 0.9, 1, 0.9, 0.8, 1.1] },
];
stars = [{ x: width * 0.2, y: height * 0.68, phase: 0 }, { x: width * 0.79, y: height * 0.22, phase: 1 }];
window.StarDrift = Object.freeze({
  start, pause, resume,
  getState: () => ({ status, score: Math.floor(score), best, lives, elapsed, ship: { x: ship.x, y: ship.y }, asteroids: asteroids.length, stars: stars.length, soundEnabled }),
});
requestAnimationFrame(frame);
