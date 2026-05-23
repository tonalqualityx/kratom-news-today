(function() {
  // Copy link buttons
  document.querySelectorAll('.copy-link').forEach(function(btn) {
    btn.addEventListener('click', function() {
      var url = btn.dataset.url;
      var feedback = btn.querySelector('.copy-feedback');
      if (navigator.clipboard) {
        navigator.clipboard.writeText(url).then(function() {
          if (feedback) {
            feedback.textContent = 'Link copied';
            setTimeout(function() {
              feedback.textContent = '';
            }, 2000);
          }
        });
      }
    });
  });
})();
