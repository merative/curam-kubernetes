/*
 * Progressive enhancement for the runbook.
 *
 * Every feature here is additive: with JavaScript disabled the page is still
 * complete and readable (all tab panels render, the nav is a plain list).
 */
(function () {
  'use strict';

  /* ------------------------------------------------------------- tabs */

  document.querySelectorAll('[data-tabs]').forEach(function (group) {
    var panels = Array.prototype.slice.call(group.querySelectorAll('.tab-panel'));
    if (panels.length < 2) return;

    var list = document.createElement('div');
    list.className = 'tab-list';
    list.setAttribute('role', 'tablist');

    var buttons = panels.map(function (panel, i) {
      var button = document.createElement('button');
      button.type = 'button';
      button.textContent = panel.dataset.label || 'Tab ' + (i + 1);
      button.setAttribute('role', 'tab');
      button.id = panel.id + '-tab';
      button.setAttribute('aria-controls', panel.id);
      panel.setAttribute('role', 'tabpanel');
      panel.setAttribute('aria-labelledby', button.id);
      list.appendChild(button);
      return button;
    });

    function select(index, focus) {
      buttons.forEach(function (button, i) {
        var on = i === index;
        button.setAttribute('aria-selected', String(on));
        button.tabIndex = on ? 0 : -1;
        panels[i].hidden = !on;
      });
      if (focus) buttons[index].focus();
      // Remember the choice so OS-specific tabs stay consistent page to page.
      try {
        localStorage.setItem('runbook-tab', buttons[index].textContent);
      } catch (e) {
        /* storage unavailable; selection is simply not persisted */
      }
    }

    list.addEventListener('click', function (event) {
      var index = buttons.indexOf(event.target);
      if (index > -1) select(index, false);
    });

    list.addEventListener('keydown', function (event) {
      var current = buttons.indexOf(document.activeElement);
      if (current < 0) return;
      var next =
        event.key === 'ArrowRight' ? (current + 1) % buttons.length
        : event.key === 'ArrowLeft' ? (current - 1 + buttons.length) % buttons.length
        : event.key === 'Home' ? 0
        : event.key === 'End' ? buttons.length - 1
        : -1;
      if (next < 0) return;
      event.preventDefault();
      select(next, true);
    });

    group.insertBefore(list, group.firstChild);
    group.classList.add('js-tabs');

    var remembered = -1;
    try {
      var saved = localStorage.getItem('runbook-tab');
      if (saved) {
        remembered = buttons.findIndex(function (b) {
          return b.textContent === saved;
        });
      }
    } catch (e) {
      /* ignore */
    }
    select(remembered > -1 ? remembered : 0, false);
  });

  /* -------------------------------------------------- copy code button */

  document.querySelectorAll('.markdown pre').forEach(function (pre) {
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'copy-btn';
    button.textContent = 'Copy';
    button.addEventListener('click', function () {
      var code = pre.querySelector('code');
      navigator.clipboard.writeText(code ? code.innerText : pre.innerText).then(
        function () {
          button.textContent = 'Copied';
          setTimeout(function () {
            button.textContent = 'Copy';
          }, 1500);
        },
        function () {
          button.textContent = 'Failed';
        }
      );
    });
    pre.appendChild(button);
  });

  /* ------------------------------------------------------- nav filter */

  var search = document.getElementById('nav-search');
  var sidebar = document.querySelector('.sidebar');

  if (search && sidebar) {
    search.addEventListener('input', function () {
      var term = search.value.trim().toLowerCase();

      sidebar.querySelectorAll('li').forEach(function (item) {
        item.classList.remove('is-filtered');
      });

      if (!term) {
        sidebar.querySelectorAll('details').forEach(function (details) {
          details.open = !!details.querySelector('a.active');
        });
        return;
      }

      sidebar.querySelectorAll('details').forEach(function (details) {
        var hits = 0;
        details.querySelectorAll('li').forEach(function (item) {
          var link = item.querySelector('a');
          if (!link) return;
          var match = link.textContent.toLowerCase().indexOf(term) > -1;
          item.classList.toggle('is-filtered', !match);
          if (match) hits++;
        });
        var group = details.closest('li');
        var groupMatch = details.querySelector('summary').textContent.toLowerCase().indexOf(term) > -1;
        if (groupMatch) {
          details.querySelectorAll('li').forEach(function (item) {
            item.classList.remove('is-filtered');
          });
          hits = 1;
        }
        details.open = hits > 0;
        if (group) group.classList.toggle('is-filtered', hits === 0);
      });

      sidebar.querySelectorAll('.nav-solo').forEach(function (item) {
        var link = item.querySelector('a');
        item.classList.toggle('is-filtered', !link || link.textContent.toLowerCase().indexOf(term) === -1);
      });
    });

    // "/" focuses the filter, matching the muscle memory of most doc sites.
    document.addEventListener('keydown', function (event) {
      var tag = (document.activeElement && document.activeElement.tagName) || '';
      if (event.key === '/' && tag !== 'INPUT' && tag !== 'TEXTAREA') {
        event.preventDefault();
        search.focus();
      }
      if (event.key === 'Escape' && document.activeElement === search) {
        search.value = '';
        search.dispatchEvent(new Event('input'));
        search.blur();
      }
    });
  }

  /* ------------------------------------------------- mobile nav toggle */

  var toggle = document.querySelector('.nav-toggle');
  if (toggle && sidebar) {
    toggle.addEventListener('click', function () {
      var open = sidebar.classList.toggle('open');
      toggle.setAttribute('aria-expanded', String(open));
    });
  }

  /* ------------------------------------------------------- toc scrollspy */

  var tocLinks = Array.prototype.slice.call(document.querySelectorAll('.toc a'));
  if (tocLinks.length && 'IntersectionObserver' in window) {
    var byId = {};
    var targets = [];

    tocLinks.forEach(function (link) {
      var target = document.getElementById(decodeURIComponent(link.hash.slice(1)));
      if (!target) return;
      byId[target.id] = link;
      targets.push(target);
    });

    var visible = new Set();
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) visible.add(entry.target.id);
          else visible.delete(entry.target.id);
        });
        // Highlight the first heading currently in the viewport band.
        var first = targets.find(function (t) {
          return visible.has(t.id);
        });
        tocLinks.forEach(function (link) {
          link.classList.remove('active');
        });
        if (first && byId[first.id]) byId[first.id].classList.add('active');
      },
      { rootMargin: '-72px 0px -70% 0px', threshold: 0 }
    );

    targets.forEach(function (target) {
      observer.observe(target);
    });
  }
})();
