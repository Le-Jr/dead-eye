# Modelos das armas e mãos

Não há arquivos de modelo no projeto. Cada arma é uma classe em `weapons/<arma>/<arma>_model.gd` que estende `WeaponModel` (`weapons/weapon_model.gd`) e monta a si mesma em `_init()`. As medidas estão em metros; o cano corre ao longo de **-Z** e passa pela origem.

## As três formas básicas

| Função | O que faz | Usada para |
|---|---|---|
| `_lathe(parent, perfil, material, at, segmentos, flat, phase)` | Peça torneada. `perfil` é uma lista de pontos `(z, raio)`. Com `segmentos = 8` e `flat = true` vira um cano octogonal. | Canos, tambor, cintas, cartuchos |
| `_loft(parent, caminho, tamanhos, material, power)` | Sólido arredondado ao longo de um caminho. Em cada ponto a seção é uma superelipse com meia-largura e meia-altura dadas. `power` 2 é elipse; mais alto fica mais quadrado. | Coronhas, cabos, guarda-mãos, braços |
| `_plate(parent, contorno, largura, material, bevel, x)` | Chapa recortada. `contorno` é a vista lateral em pontos `(z, y)`; as bordas são chanfradas. | Caixas de culatra, cães, gatilhos, miras |

Além dessas: `_wire` (vareta por uma lista de pontos), `_arc` (pontos de um arco, para guarda-matos), `_cartridge_mesh`, `_screw`, `_engrave`, e as primitivas `_box`, `_tube`, `_capsule`, `_ball`, `_ring`.

Todas escrevem as próprias normais e ordenam os triângulos sozinhas (`_tri`), então não é preciso pensar em sentido horário/anti-horário.

## Materiais

`steel()` (azulado), `silver()` (níquel), `brass()`, `case_hardened()` (aço cementado, manchado), `wood()` (nogueira com veio), `ivory()`, `lead()`, `spent_brass()`, `skin()`, `sleeve()`, `cuff()`. São compartilhados: mudar um muda todas as armas.

## O que uma arma precisa manter

O código da arma (`revolver.gd` etc.) nunca toca em malhas. Ele chama `model.play_action(nome, duração, args)` e pede dois marcadores. Ao refazer um modelo, mantenha:

- os marcadores `Muzzle` e `Eject`;
- os nós animados (`_hammer`, `_cylinder`, `_lever`, `_barrels`, `_block`, `_peep`) e seus pivôs;
- as alturas de mira descritas no comentário do topo de cada modelo, que casam com `ads_position` em `weapons/data/*.tres`;
- as ações tratadas em `_play_procedural`.

## Mãos

`_hand(parent, side, curls, thumb, thumb_curl, arm)` cria uma mão fechada com antebraço e manga.

- No espaço da própria mão o punho fica na origem, os dedos apontam para -Z e fecham para -Y (lado da palma).
- `side`: 1 mão direita, -1 esquerda.
- `curls`: um trio `[nó, meio, ponta]` em radianos por dedo, do indicador ao mínimo.
- `arm`: direção em que o antebraço sai do punho.

`_place_hand(hand, ponto, across, back, along)` encosta a palma em `ponto`: `across` é a direção do +X da mão e `back` é para onde o dorso aponta. `along` maior aproxima o contato dos nós dos dedos, para empunhaduras finas.

Cada arma tem a mão direita na empunhadura. As armas longas têm a esquerda sob o guarda-mão, guardada em `_support_hand`.

### A mão que carrega

`_add_load_hand()` cria uma mão esquerda no espaço do modelo, e não no nó `Pose` que inclina na recarga, para o braço continuar vindo do lado do atirador. `_begin_loading()` faz a mão de apoio soltar a arma e mostra a mão de carga; `_animate_insert()` registra o cartucho em movimento e a mão o segue; `_end_loading()` desfaz.

## Conferir

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_windowed.ps1 res://tests/model_review.tscn
powershell -ExecutionPolicy Bypass -File tools/run_windowed.ps1 res://tests/model_review.tscn 1920x540 0
```

A primeira linha grava `output/review/models.png` com as quatro armas em quatro vistas (lado direito, frente-esquerda, visão do atirador, meio da recarga). A segunda renderiza só o revólver, maior.

## Limitações conhecidas

- As poses das mãos foram ajustadas por capturas paradas. A recarga em movimento e a mira com as mãos não foram vistas em jogo.
- A mão é rígida: a palma não se curva, então empunhaduras finas parecem um pouco folgadas.
- O polegar não acompanha o cão ao engatilhar.
