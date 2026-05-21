(function() {
  // Mobile nav toggle
  var navToggle = document.querySelector('.nav-toggle');
  var navMenu = document.querySelector('.nav-menu');

  if (navToggle && navMenu) {
    navToggle.addEventListener('click', function() {
      var expanded = navToggle.getAttribute('aria-expanded') === 'true';
      navToggle.setAttribute('aria-expanded', !expanded);
      navMenu.classList.toggle('is-open');
    });
  }

  // Copy link buttons
  document.querySelectorAll('.copy-link').forEach(function(btn) {
    btn.addEventListener('click', function() {
      var url = btn.dataset.url;
      if (navigator.clipboard) {
        navigator.clipboard.writeText(url).then(function() {
          var originalText = btn.textContent;
          btn.textContent = 'Copied!';
          setTimeout(function() {
            btn.textContent = originalText;
          }, 2000);
        });
      }
    });
  });
})();
