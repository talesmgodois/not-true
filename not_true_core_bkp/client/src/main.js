import './main.css'

const go = new Go();
WebAssembly.instantiateStreaming(
  fetch("/static/main.wasm"),
  go.importObject
)
.then((result) => go.run(result.instance))
.catch((err) => console.error("WASM initialization failed:", err));

// DOM event handlers
document.getElementById('searchForm')?.addEventListener('submit', async (e) => {
  e.preventDefault();
  const searchTerm = document.getElementById('searchInput').value.trim();
  updateURL(searchTerm);
  await performSearch(searchTerm);
});

async function performSearch(term) {
  try {
    const response = await fetch(`/api/search?q=${encodeURIComponent(term)}`);
    const items = await response.json();
    updateItems(items);
  } catch (error) {
    console.error('Search failed:', error);
  }
}

function updateItems(items) {
  const container = document.getElementById('items-container');
  if (!container) return;
  
  container.innerHTML = items.length > 0 
    ? items.map(item => `
        <div class="item">
          <h3>${escapeHtml(item.name)}</h3>
          <p>${escapeHtml(item.description)}</p>
        </div>
      `).join('')
    : '<div class="no-results">No items found</div>';
}

function escapeHtml(unsafe) {
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function updateURL(searchTerm) {
  const url = new URL(window.location);
  if (searchTerm) {
    url.searchParams.set('q', searchTerm);
  } else {
    url.searchParams.delete('q');
  }
  window.history.pushState({}, '', url);
}
