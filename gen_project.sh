#!/bin/bash

# Initialize project
PROJECT_NAME="not_true_core"
mkdir -p $PROJECT_NAME/{client/src,service/home/templates,static,shared/templates,shared/model}
cd $PROJECT_NAME

# Create basic files
touch encore.app \
       air.toml \
       client/vite.config.js \
       client/src/main.js \
       client/src/main.css \
       service/home/home.go \
       service/home/templates/home.gotmpl \
       shared/model/item.go \
       shared/templates/search.gotmpl

# Generate content for each file

# 1. Encore config
cat > encore.app << 'EOL'
name: "$PROJECT_NAME"
EOL

# 2. Air config for live reload
cat > air.toml << 'EOL'
[build]
cmd = "encore run"
bin = "encore"
full_bin = "encore run"
include_ext = ["go", "gotmpl", "html", "css"]
exclude_dir = ["node_modules", "client/wasm"]
EOL

# 3. Vite config
cat > client/vite.config.js << 'EOL'
import { defineConfig } from 'vite'

export default defineConfig({
  build: {
    manifest: true,
    outDir: '../static',
    rollupOptions: {
      input: './src/main.js'
    }
  },
  server: {
    port: 3000,
    cors: true,
    strictPort: true,
    proxy: {
      '/api': 'http://localhost:4000',
      '/static': 'http://localhost:4000'
    }
  }
})
EOL

# 4. Main client JS
cat > client/src/main.js << 'EOL'
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
EOL

# 5. Basic CSS
cat > client/src/main.css << 'EOL'
.item { 
  margin: 20px 0; 
  padding: 10px; 
  border: 1px solid #ddd; 
}
.search-box { 
  margin: 20px 0; 
}
.no-results {
  color: #666;
  font-style: italic;
}
EOL

# 6. Main Go service file
cat > service/home/home.go << 'EOL'
package home

import (
	"embed"
	"encoding/json"
	"html/template"
	"net/http"
	"os"
)

//go:embed templates/*
var templateFS embed.FS

//go:embed ../../client/dist/manifest.json
var manifestFS embed.FS

type Manifest struct {
	MainJS struct {
		File    string   `json:"file"`
		CSS     []string `json:"css"`
		Imports []string `json:"imports"`
	} `json:"src/main.js"`
}

type Item struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

var (
	templates *template.Template
	manifest  Manifest
)

func init() {
	templates = template.Must(template.New("").ParseFS(templateFS, "templates/*.gotmpl"))
	
	if os.Getenv("ENVIRONMENT") != "development" {
		manifestFile, _ := manifestFS.ReadFile("client/dist/manifest.json")
		json.Unmarshal(manifestFile, &manifest)
	}
}

//encore:api public path=/
func Home(w http.ResponseWriter, r *http.Request) {
	searchQuery := r.URL.Query().Get("q")
	items := searchItems(searchQuery)

	data := struct {
		SearchQuery string
		Items       []Item
		Assets      map[string]string
	}{
		SearchQuery: searchQuery,
		Items:       items,
		Assets:      getAssetPaths(),
	}

	w.Header().Set("Content-Type", "text/html")
	templates.ExecuteTemplate(w, "home.gotmpl", data)
}

func searchItems(query string) []Item {
	// Simulated database search
	return []Item{
		{Name: "Result 1 for " + query, Description: "Description 1"},
		{Name: "Result 2 for " + query, Description: "Description 2"},
	}
}

func getAssetPaths() map[string]string {
	if os.Getenv("ENVIRONMENT") == "development" {
		return map[string]string{
			"mainJS":  "http://localhost:3000/src/main.js",
			"mainCSS": "http://localhost:3000/src/main.css",
		}
	}
	
	return map[string]string{
		"mainJS":  "/static/" + manifest.MainJS.File,
		"mainCSS": "/static/" + manifest.MainJS.CSS[0],
	}
}

//encore:api public path=/api/search
func Search(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	items := searchItems(query)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(items)
}
EOL

# 7. Go template
cat > service/home/templates/home.gotmpl << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Search App</title>
    {{ if .Assets.mainCSS }}
    <link rel="stylesheet" href="{{.Assets.mainCSS}}">
    {{ end }}
</head>
<body>
    <div class="search-box">
        <form id="searchForm">
            <input type="text" 
                   id="searchInput" 
                   name="q" 
                   value="{{.SearchQuery}}"
                   placeholder="Search items..."
                   autocomplete="off">
            <button type="submit">Search</button>
        </form>
    </div>

    <div id="items-container">
        {{range .Items}}
        <div class="item">
            <h3>{{.Name}}</h3>
            <p>{{.Description}}</p>
        </div>
        {{else}}
        <div class="no-results">No items found</div>
        {{end}}
    </div>

    {{ if .Assets.mainJS }}
    <script type="module" src="{{.Assets.mainJS}}"></script>
    {{ end }}
</body>
</html>
EOL

# 8. Shared model
cat > shared/model/item.go << 'EOL'
package model

type Item struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}
EOL

# 9. Shared template component
cat > shared/templates/search.gotmpl << 'EOL'
{{ define "SearchBox" }}
<div class="search-box">
  <form id="searchForm">
    <input type="text" 
           id="searchInput" 
           name="q" 
           value="{{.SearchQuery}}"
           placeholder="Search items..."
           autocomplete="off">
    <button type="submit">Search</button>
  </form>
</div>
{{ end }}
EOL

# Create package.json
cat > package.json << 'EOL'
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "scripts": {
    "dev:go": "ENVIRONMENT=development air",
    "dev:vite": "vite",
    "build:client": "vite build",
    "generate:types": "openapi-generator-cli generate -i http://localhost:4000/api -g typescript -o ./client/src/types",
    "dev": "concurrently \"npm run dev:go\" \"npm run dev:vite\" \"npm run generate:types -- --watch\"",
    "build": "npm run build:client && GOOS=js GOARCH=wasm go build -o static/main.wasm ./client/main.go"
  },
  "dependencies": {
    "vite": "^5.0.0"
  },
  "devDependencies": {
    "@openapitools/openapi-generator-cli": "^2.7.0",
    "concurrently": "^8.2.2"
  }
}
EOL

# Initialize Go module
go mod init $PROJECT_NAME
go mod tidy

# Install required tools
echo "Installing required tools..."
go install github.com/cosmtrek/air@latest
go install github.com/openapitools/openapi-generator-cli@latest

# Initialize npm
npm install

echo ""
echo "Project setup complete!"
echo "To start development:"
echo "1. cd $PROJECT_NAME"
echo "2. npm run dev"
echo ""
echo "For production build:"
echo "1. npm run build"
echo "2. encore run"