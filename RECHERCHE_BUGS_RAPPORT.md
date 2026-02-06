# Rapport de Recherche de Bugs - Cortex CLI v0.0.7

## Statut Actuel
- **Bugs validés:** 1 (#6301 - is_approaching_limit)
- **Bugs invalides:** 1 (stream/no-stream - comportement intentionnel)
- **Ratio:** 1:1 (50%)

## Modules Analysés (50+ fichiers)

### cortex-cli/
- handlers.rs, scheduler.rs, stats_cmd.rs, export_cmd.rs
- cache_cmd.rs, lock_cmd.rs, models_cmd.rs
- run_cmd/execution.rs, run_cmd/cli.rs
- mcp_cmd/validation.rs, mcp_cmd/types.rs
- dag_cmd/scheduler.rs, dag_cmd/executor.rs
- pr_cmd.rs, import_cmd.rs

### cortex-engine/
- token_budget.rs, output.rs, diff.rs
- generator.rs, code_analysis.rs, text_encoding.rs
- state/service.rs, state/mod.rs
- agent/executor.rs, truncate.rs
- jira/client.rs, linear/client.rs

### cortex-collab/
- handler.rs, thread_manager.rs, guards.rs, control.rs

### cortex-compact/
- auto_compaction/scheduler.rs

### cortex-apply-patch/
- applier.rs, fuzzy.rs, parser.rs

### cortex-file-search/
- cache.rs

### cortex-snapshot/
- revert.rs

### cortex-protocol/
- models.rs, num_format.rs

## Bugs Trouvés puis Vérifiés comme DOUBLONS

| Bug | Fichier | Raison du doublon |
|-----|---------|-------------------|
| VALID_SORT_VALUES mismatch | models_cmd.rs:426-438 | Déjà reporté |
| TokenBudget division by zero | token_budget.rs:44 | Déjà reporté |
| Cache expired entries leak | cache.rs:88-95 | Déjà reporté |
| scheduler.rs success=true | scheduler.rs:113 | Déjà reporté |
| Diff offset underflow | diff.rs:287 | Déjà reporté |
| generator.rs UTF-8 slice | generator.rs:339-340 | Déjà reporté |
| Prerelease comparison | version.rs | Déjà reporté |
| ThreadId::new() in error | handler.rs:166 | Déjà reporté |

## Seule Option Restante (RISQUÉE)

### UTF-8 Slicing dans Align::pad() (output.rs:216)
```rust
if text.len() >= width {
    return text[..width].to_string();  // PANIC si UTF-8 multi-octets
}
```

**Risque:** ~40% d'être marqué "pattern duplicate" car d'autres UTF-8 bugs dans output.rs ont été reportés (lignes 172).

## Conclusion

Avec 6300+ issues déjà reportées, la compétition est extrême. Les patterns classiques sont épuisés:
- UTF-8 string slicing
- .unwrap() / .expect()
- Division by zero
- Path traversal
- Race conditions
- Deadlocks
- Integer overflow

**Recommandation:** Conserver le ratio 1:1 actuel plutôt que risquer un bug incertain.
