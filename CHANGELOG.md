# Histórico

O projeto foi construído em fases em 14/11/2026, antes de existir repositório. Os commits iniciais agrupam o código por funcionalidade; eles não são estados intermediários que rodavam sozinhos. Este arquivo registra a ordem real do trabalho.

## Mãos refeitas e fumaça nova (15/11/2026)

- **Empunhadura:** a mão direita envolvia o cabo por trás e por baixo, com o polegar solto no ar e o braço vindo do meio da tela. Agora a palma fica no lado direito, o dedo médio atrás do guarda-mato, o indicador no gatilho e o polegar dá a volta no cabo. Nas armas longas a mão abraça o delgado da coronha por baixo, com o polegar ao longo da caixa.
- **Malha da mão:** músculo na base do polegar, membrana entre polegar e indicador e calcanhar da mão (`wrap`).
- `_grip_hand` em `weapons/weapon_model.gd` posiciona a mão a partir do eixo do cabo; as quatro armas usam.
- Mão de apoio com os dedos mais fechados: as pontas subiam acima do cano e apareciam ao lado da mira.
- No rifle de alavanca a mão acompanha o laço quando a alavanca abre.
- **Fumaça:** deixou de ser um punhado de discos brancos opacos. São três emissores: um jato rápido, uma nuvem rala que cresce, se esgarça com turbulência e vai com o vento, e um fio que continua saindo do cano. A textura é um disco roído por ruído (quatro variações); a fumaça some suavemente contra o chão, as paredes e perto do olho, e escurece à noite (`FX.smoke_tint`).
- Cenas `tests/hand_review.tscn` e `tests/shot_review.tscn`.

## Revólver e munição refinados (15/11/2026)

- **Tambor:** as seis câmaras são furadas de lado a lado, com um cartucho inteiro em cada uma; entalhes de trava; fica um aro à frente do escudo, como no revólver de verdade.
- **Cano:** alma de verdade na boca, com coroa, no lugar do disco escuro.
- **Armação:** costas em curva contínua atrás do cão, frente arredondada sob o cano, guarda-mato em tira chata.
- **Munição:** estojo com aro, espoleta e projétil de ponta redonda; estojo deflagrado com a boca aberta e a marca do percussor; cartucho de espingarda com culote, tubo de papel e bucha. Vale para os cartuchos soltos da recarga das quatro armas.
- Os estojos ejetados usam a mesma malha (antes eram cilindros lisos; os da coach gun eram cilindros de latão de 6,5 cm).
- `_plate` sombreia dobras suaves como curva; `_lathe` ganhou pontas abertas e superfície interna.
- Cena `tests/ammo_review.tscn`; `hand_review` aceita `bare`.

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

Som e música (só medidos), valores de sensação, limiares de estrelas, mãos e fumaça em movimento (só capturas paradas).
