# Histórico

O projeto foi construído em fases em 14/11/2026, antes de existir repositório. Os commits iniciais agrupam o código por funcionalidade; eles não são estados intermediários que rodavam sozinhos. Este arquivo registra a ordem real do trabalho.

## Modelos e mãos

- Novo conjunto de modelagem em `weapons/weapon_model.gd`: peças torneadas, sólidos arredondados e chapas chanfradas, com normais próprias.
- Revólver, rifle de alavanca, coach gun e Sharps refeitos: tambor com caneluras, canos octogonais, coronhas arredondadas, soleira em crescente, chapas de fecho, cães com esporão, guarda-matos em arco.
- Materiais novos: aço cementado, nogueira com veio, marfim, pele, manga.
- Mãos e antebraços do jogador em todas as armas; a mão esquerda solta a arma e leva o cartucho na recarga.
- Cena `tests/model_review.tscn` e `tools/run_windowed.ps1`.

## Fases 4–7 refeitas

- **Interface:** tema com Rye + Bitter, HUD em etiquetas de papel, carimbos de pontuação, menu-cartaz com recordes, pausa, resultados com estrelas, configurações em abas, remapeamento com restauração.
- **Efeitos sonoros:** 111 arquivos em 32 chaves, sintetizados com NumPy/SciPy; impactos por superfície, cápsulas, Dead Eye com batimento.
- **Música:** cinco temas em três camadas e três vinhetas, compostos em MIDI e renderizados com FluidSynth + GeneralUser GS; camadas seguem o jogo.
- **Cenário:** igreja, moinho, barris, chão texturizado, céu e noite estrelada.

### Correções feitas nessa etapa

- A pausa não fechava com Esc porque o HUD parava junto com o jogo.
- Remapear uma tecla deixava o botão do mouse antigo ativo: teclado e mouse agora dividem um espaço por ação.
- O eco dos tiros ignorava o volume de efeitos: o bus de eco passou a alimentar o de SFX.
- Uma carga de chumbo tocava um som de impacto por bago; agora toca um.
- O filtro da câmera lenta abafava também a interface; ficou só nos efeitos.
- `tools/check.ps1` dependia de um caminho fixo do Godot; agora procura no PATH.
- Removidos `levels/greybox_range.tscn` (apontava para um script inexistente) e `ui/debug_hud.gd`.

## Fases 4–7, primeira passada (Codex)

HUD, menu, pausa, configurações, áudio e música sintetizados, cidade procedural, Dead Eye, Long Shot e modelos estilizados, em versão inicial.

## Fases 1–3

Controle em primeira pessoa, quatro armas com suas ações, balística com queda e vento, alvos, Gallery, Quick Draw, pontuação com combo, estilo e truques, salvamento.

## Nunca verificado por uma pessoa

Som e música (só medidos), valores de sensação, limiares de estrelas, recarga em movimento com as mãos.
