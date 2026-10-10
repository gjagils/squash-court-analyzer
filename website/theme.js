// Weergave of the website: Systeem / Licht / Donker (docs/style/README.md,
// "Lichte modus — warm licht"). The inline script in every <head> already set
// <html data-theme> before the first paint (Donker unless the visitor chose
// otherwise); this file fills each [data-theme-choice] slot with the control,
// stores the choice and follows the system setting while "Systeem" is chosen.
(function () {
  var KEY = 'sa-theme';
  var root = document.documentElement;
  var media = window.matchMedia ? window.matchMedia('(prefers-color-scheme: light)') : null;
  var OPTIONS = [['system', 'Systeem'], ['light', 'Licht'], ['dark', 'Donker']];

  function valid(choice) { return choice === 'light' || choice === 'system' ? choice : 'dark'; }

  function stored() {
    try { return valid(localStorage.getItem(KEY)); } catch (e) { return 'dark'; }
  }

  function apply(choice) {
    var theme = choice === 'system' ? (media && media.matches ? 'light' : 'dark') : choice;
    root.setAttribute('data-theme', theme);
    root.setAttribute('data-theme-choice', choice);
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', theme === 'light' ? '#F7F3ED' : '#000000');
  }

  var selects = [];
  function sync(choice) {
    apply(choice);
    selects.forEach(function (select) { select.value = choice; });
  }

  function build(slot, index) {
    var id = 'theme-choice-' + index;
    var label = document.createElement('label');
    label.setAttribute('for', id);
    label.textContent = 'Weergave';
    var select = document.createElement('select');
    select.id = id;
    OPTIONS.forEach(function (option) {
      var node = document.createElement('option');
      node.value = option[0];
      node.textContent = option[1];
      select.appendChild(node);
    });
    select.value = stored();
    select.addEventListener('change', function () {
      var choice = valid(select.value);
      try { localStorage.setItem(KEY, choice); } catch (e) { /* private mode: only this page */ }
      sync(choice);
    });
    slot.classList.add('theme-choice');
    slot.replaceChildren(label, select);
    selects.push(select);
  }

  function start() {
    var slots = document.querySelectorAll('[data-theme-choice-slot]');
    for (var i = 0; i < slots.length; i++) build(slots[i], i);
    sync(stored());
  }

  // "Systeem" follows a change of the system setting while the page is open
  if (media) {
    var follow = function () { if (stored() === 'system') apply('system'); };
    if (media.addEventListener) media.addEventListener('change', follow);
    else if (media.addListener) media.addListener(follow);
  }
  // A choice made in another tab of the site
  window.addEventListener('storage', function (event) { if (event.key === KEY) sync(stored()); });

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
