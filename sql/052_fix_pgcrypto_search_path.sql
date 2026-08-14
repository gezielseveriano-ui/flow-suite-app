-- ============================================================================
-- FactoryView -- Fix: no Supabase o pgcrypto fica instalado no schema
-- "extensions", não em "public". As funções de PIN (_checar_pin e
-- definir_pin_colaborador) só tinham "public" no search_path, então crypt()
-- não era encontrado em tempo de execução. Adiciona "extensions" também.
-- ============================================================================

alter function public._checar_pin(text, text) set search_path = public, extensions;
alter function public.definir_pin_colaborador(text, text) set search_path = public, extensions;
