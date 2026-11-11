// "Stel een vraag" boven de handleiding (Gerd-Jan, 10 November 2026). The box
// goes where <div data-vraag data-platform="iphone|android" data-lang="nl|en">
// stands; the answer comes from /api/vraag (Workers AI, from this manual only).
(function () {
  var slot = document.querySelector('[data-vraag]');
  if (!slot) return;
  var en = slot.getAttribute('data-lang') === 'en';
  var t = en ? {
    title: 'Ask a question', hint: 'For example: How do I share a match with a player?', send: 'Ask',
    busy: 'Looking it up…', fail: 'That did not work. Try again in a moment, or email info@squashanalyzer.com.',
    many: 'Many questions just now. Try again in a minute.', read: 'Read more:',
    note: 'The answer comes from this manual, made by AI (Cloudflare). We keep your question, without your name or IP address, to improve the app and the manual. Don\'t type personal details.'
  } : {
    title: 'Stel een vraag', hint: 'Bijvoorbeeld: Hoe stuur ik een wedstrijd naar een speler?', send: 'Vraag',
    busy: 'Even zoeken…', fail: 'Dat lukte niet. Probeer het zo nog eens, of mail info@squashanalyzer.com.',
    many: 'Veel vragen net. Probeer het over een minuut weer.', read: 'Lees verder:',
    note: 'Het antwoord komt uit deze handleiding en wordt gemaakt met AI (Cloudflare). We bewaren je vraag, zonder je naam of IP-adres, om de app en de handleiding te verbeteren. Typ geen persoonlijke gegevens.'
  };
  slot.className = 'tile vraag';
  slot.innerHTML =
    '<div><h2><span class="icon"><span class="ms" aria-hidden="true">psychology</span></span>' + t.title + '</h2>' +
    '<form class="vraag-form"><input type="text" maxlength="300" required aria-label="' + t.title + '" placeholder="' + t.hint + '">' +
    '<button type="submit">' + t.send + '</button></form>' +
    '<div class="vraag-answer" aria-live="polite"></div><p class="vraag-note">' + t.note + '</p></div>';
  var form = slot.querySelector('form');
  var input = slot.querySelector('input');
  var button = slot.querySelector('button');
  var out = slot.querySelector('.vraag-answer');
  // Opened from the speech bubble in the app (…#vraag): straight to the box
  if (location.hash === '#vraag') {
    slot.scrollIntoView({ block: 'start' });
    input.focus();
  }
  function show(text, links) {
    out.textContent = '';
    var p = document.createElement('p');
    p.textContent = text;
    out.appendChild(p);
    if (links && links.length) {
      var more = document.createElement('p');
      more.className = 'vraag-links';
      more.appendChild(document.createTextNode(t.read + ' '));
      links.forEach(function (link, i) {
        if (i > 0) more.appendChild(document.createTextNode(' · '));
        var a = document.createElement('a');
        a.href = link.href;
        a.textContent = link.title;
        more.appendChild(a);
      });
      out.appendChild(more);
    }
  }
  form.addEventListener('submit', function (event) {
    event.preventDefault();
    var question = input.value.trim();
    if (question.length < 3) return;
    button.disabled = true;
    show(t.busy);
    fetch('/api/vraag', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question: question, lang: en ? 'en' : 'nl', platform: slot.getAttribute('data-platform'), source: 'web' })
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (j) { return { status: r.status, body: j }; });
    }).then(function (res) {
      if (res.status === 429) show(t.many);
      else if (res.status !== 200 || !res.body.answer) show(t.fail);
      else show(res.body.answer, res.body.links);
    }).catch(function () { show(t.fail); }).then(function () { button.disabled = false; });
  });
})();
