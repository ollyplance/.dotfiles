# ==============================================================================
# KUBERNETES HELPERS (portable)
# ==============================================================================

# Tmux pane-level Kubeconfig Isolation: each pane gets its own copy of the
# kubeconfig so `kubectl config use-context` in one tab doesn't leak to others.
if [ -n "${TMUX_PANE:-}" ]; then
  local_pane_id="${TMUX_PANE//\%/}"
  local_kubeconfig="/tmp/kubeconfig-tmux-${local_pane_id}"

  if [ ! -f "$local_kubeconfig" ]; then
    # If a KUBECONFIG is inherited from a parent pane and exists, copy it to initialize
    if [ -n "${KUBECONFIG:-}" ] && [ -f "$KUBECONFIG" ] && [[ "$KUBECONFIG" == /tmp/kubeconfig-tmux-* ]]; then
      cp "$KUBECONFIG" "$local_kubeconfig"
    # Otherwise, copy the global kubeconfig if it exists
    elif [ -f "$HOME/.kube/config" ]; then
      cp "$HOME/.kube/config" "$local_kubeconfig"
    fi
  fi

  export KUBECONFIG="$local_kubeconfig"
  unset local_pane_id local_kubeconfig
fi

# Helper to display or change kubeconfig contexts easily
function kuse() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo "Active KUBECONFIG: $KUBECONFIG"
    if [[ -f "$KUBECONFIG" ]]; then
      echo "Context:   $(kubectl config current-context 2>/dev/null || echo 'None')"
      echo "Namespace: $(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo 'default')"
    fi
    return 0
  fi
  
  case "$target" in
    global|default)
      export KUBECONFIG="$HOME/.kube/config"
      echo "Switched to global/default KUBECONFIG: $KUBECONFIG"
      ;;
    pane)
      PANE_ID="${TMUX_PANE#%}"
      export KUBECONFIG="/tmp/kubeconfig-tmux-$PANE_ID"
      echo "Switched to pane-isolated KUBECONFIG: $KUBECONFIG"
      ;;
    reset)
      PANE_ID="${TMUX_PANE#%}"
      local pane_config="/tmp/kubeconfig-tmux-$PANE_ID"
      if [[ -f "$HOME/.kube/config" ]]; then
        cp "$HOME/.kube/config" "$pane_config"
        export KUBECONFIG="$pane_config"
        echo "Reset current pane's config to a fresh copy of the global config."
      else
        echo "Error: Global config $HOME/.kube/config not found."
      fi
      ;;
    *)
      if [[ -f "$target" ]]; then
        export KUBECONFIG="$target"
        echo "Switched KUBECONFIG to: $KUBECONFIG"
      elif [[ -f "$HOME/.kube/$target" ]]; then
        export KUBECONFIG="$HOME/.kube/$target"
        echo "Switched KUBECONFIG to: $KUBECONFIG"
      else
        echo "File not found: $target"
        return 1
      fi
      ;;
  esac
}

# Interactive context switcher using fzf (sorted by most recently used and pretty-printed)
function kctx() {
  local hist_file="$HOME/.kube_context_history"
  local available
  available=$(kubectl config get-contexts -o name 2>/dev/null)
  
  local sorted_contexts
  sorted_contexts=$(echo "$available" | awk -v hist_file="$hist_file" '
    BEGIN {
      cmd = "(tac " hist_file " || tail -r " hist_file ") 2>/dev/null"
      while ((cmd | getline line) > 0) {
        if (line != "") {
          history[line] = 1
          history_list[++count] = line
        }
      }
      close(cmd)
    }
    { available[$1] = 1 }
    END {
      for (i = 1; i <= count; i++) {
        ctx = history_list[i]
        if (ctx in available && !printed[ctx]) {
          print ctx
          printed[ctx] = 1
        }
      }
      for (ctx in available) {
        if (!printed[ctx]) {
          print ctx
        }
      }
    }
  ')

  # Pretty-print the contexts list for fzf
  local formatted_list=""
  local ctx
  while read -r ctx; do
    if [[ -z "$ctx" ]]; then continue; fi
    if [[ "$ctx" =~ ^gke_([^_]+)_([^_]+)_(.+)$ ]]; then
      local project="${match[1]}"
      local zone="${match[2]}"
      local cluster="${match[3]}"
      formatted_list+="$(printf "%-70s %s\n" "$cluster/$project/$zone" "$ctx")\n"
    else
      formatted_list+="$(printf "%-70s %s\n" "$ctx" "$ctx")\n"
    fi
  done <<< "$sorted_contexts"
  
  local selection
  selection=$(echo -e "$formatted_list" | fzf --no-sort --height 40% --reverse --prompt="Select Kube Context (MRU): ")
  if [[ -n "$selection" ]]; then
    local context
    context=$(echo "$selection" | awk '{print $NF}')
    kubectl config use-context "$context"
    # Record context change in history
    mkdir -p "$(dirname "$hist_file")"
    echo "$context" >> "$hist_file"
  fi
}

# Interactive namespace switcher using fzf
function kns() {
  local ns
  ns=$(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | fzf --height 40% --reverse --prompt="Select Namespace: ")
  if [[ -n "$ns" ]]; then
    kubectl config set-context --current --namespace="$ns"
  fi
}
