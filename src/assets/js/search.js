(function() {
  const searchInput = document.getElementById('search-input');
  const resultsContainer = document.getElementById('search-results');
  if (!searchInput || !resultsContainer) return;

  let searchIndex = null;

  // Load search index
  async function loadIndex() {
    try {
      const response = await fetch('/search-index.json');
      searchIndex = await response.json();
    } catch (err) {
      resultsContainer.innerHTML = '<p>Search index could not be loaded.</p>';
    }
  }

  // Search function
  function search(query) {
    if (!searchIndex || !query.trim()) {
      resultsContainer.innerHTML = '<p class="search-placeholder">Enter a search term to find briefings.</p>';
      return;
    }

    const terms = query.toLowerCase().split(/\s+/);
    const results = searchIndex.filter(function(item) {
      const searchable = (item.title + ' ' + item.summary + ' ' + item.tags.join(' ') + ' ' + item.excerpt).toLowerCase();
      return terms.every(function(term) {
        return searchable.indexOf(term) !== -1;
      });
    });

    if (results.length === 0) {
      resultsContainer.innerHTML = '<p>No briefings found for "' + escapeHtml(query) + '".</p>';
      return;
    }

    let html = '<p class="search-count">' + results.length + ' result' + (results.length !== 1 ? 's' : '') + ' for "' + escapeHtml(query) + '"</p>';

    results.forEach(function(item) {
      html += '<article class="briefing-card">';
      html += '<span class="beat-label beat-' + escapeHtml(item.beat) + '">' + escapeHtml(item.beat) + '</span>';
      html += '<h3><a href="' + escapeHtml(item.url) + '">' + escapeHtml(item.title) + '</a></h3>';
      html += '<time>' + escapeHtml(item.date) + '</time>';
      html += '<p>' + escapeHtml(item.summary) + '</p>';
      html += '</article>';
    });

    resultsContainer.innerHTML = html;
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  // Initialize
  loadIndex();

  // Handle URL query parameter
  var params = new URLSearchParams(window.location.search);
  var initialQuery = params.get('q');
  if (initialQuery) {
    searchInput.value = initialQuery;
    // Wait for index to load then search
    var checkIndex = setInterval(function() {
      if (searchIndex) {
        clearInterval(checkIndex);
        search(initialQuery);
      }
    }, 100);
  }

  // Live search on input
  var debounceTimer;
  searchInput.addEventListener('input', function() {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(function() {
      search(searchInput.value);
    }, 200);
  });

  // Handle form submit
  searchInput.closest('form').addEventListener('submit', function(e) {
    e.preventDefault();
    search(searchInput.value);
  });
})();
