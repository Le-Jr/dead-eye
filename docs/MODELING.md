# Modelos das armas e mãos

Não há arquivos de modelo no projeto. Cada arma é uma classe em `weapons/<arma>/<arma>_model.gd` que estende `WeaponModel` (`weapons/weapon_model.gd`) e monta a si mesma em `_init()`. As medidas estão em metros; o cano corre ao longo de **-Z** e passa pela origem.

## As três formas básicas

| Função | O que faz | Usada para |
|---|---|---|
| `_lathe(parent, perfil, material, at, segmentos, flat, phase, caps, inside)` | Peça torneada. `perfil` é uma lista de pontos `(z, raio)`. Com `segmentos = 8` e `flat = true` vira um cano octogonal. `caps` fecha as pontas (1 a primeira, 2 a última, 3 as duas, 0 nenhuma) e `inside` vira a superfície para dentro, para furos. | Canos, tambor, cintas, cartuchos, câmaras |
| `_loft(parent, caminho, tamanhos, material, power)` | Sólido arredondado ao longo de um caminho. Em cada ponto a seção é uma superelipse com meia-largura e meia-altura dadas. `power` 2 é elipse; mais alto fica mais quadrado. | Coronhas, cabos, guarda-mãos, braços |
| `_plate(parent, contorno, largura, material, bevel, x)` | Chapa recortada. `contorno` é a vista lateral em pontos `(z, y)`; as bordas são chanfradas. | Caixas de culatra, cães, gatilhos, miras |

Além dessas: `_wire` (vareta por uma lista de pontos), `_arc` (pontos de um arco, para guarda-matos), `_bore` (furo de verdade na boca do cano), `_screw`, `_engrave`, e as primitivas `_box`, `_tube`, `_capsule`, `_ball`, `_ring`.

`lathe_mesh(...)` é a versão estática de `_lathe`: devolve só a malha e, com `onto`, acrescenta uma superfície a uma malha que já existe. Serve para peças de mais de um material.

`_plate` sombreia como curva qualquer dobra suave do contorno (menos de uns 40° entre uma aresta e a seguinte) e mantém vivos os cantos de verdade. Para uma curva lisa basta dar mais pontos ao contorno.

Para um cano com alma: termine o perfil do cano no raio do furo, com `caps = 1`, e chame `_bore(parent, ponto_da_boca, raio)`. Só o revólver usa por enquanto; as armas longas ainda têm o disco escuro de `_muzzle_rim`.

Todas escrevem as próprias normais e ordenam os triângulos sozinhas (`_tri`), então não é preciso pensar em sentido horário/anti-horário.

## Materiais

`steel()` (azulado), `silver()` (níquel), `brass()`, `case_hardened()` (aço cementado, manchado), `wood()` (nogueira com veio), `ivory()`, `lead()`, `spent_brass()`, `skin()`, `sleeve()`, `cuff()`. São compartilhados: mudar um muda todas as armas.

## Munição

`_cartridge_mesh(parent, raio, comprimento, shell)` cria um cartucho deitado no eixo do cano, com a base na origem e o projétil para -Z: estojo de latão com aro, espoleta no alojamento e projétil de chumbo de ponta redonda. Com `shell = true` é um cartucho de espingarda (culote de latão, tubo de papel, bucha de cartão).

`set_cartridge_spent(cartucho, true)` transforma em estojo deflagrado: latão fuliginoso, sem projétil, boca aberta e a marca do percussor na espoleta.

`case_mesh(raio, comprimento, shell, spent)` devolve só o estojo, em cache. É a mesma malha que `FX.casing` joga para fora da arma, então o que cai no chão é igual ao que estava na câmara.

No revólver cada câmara é furada de lado a lado e tem um cartucho inteiro dentro (`_rounds`): o aro e a espoleta aparecem atrás, a ponta do projétil pela frente. A ação `chambers` mostra, esconde ou marca como deflagrado cada um.

## O que uma arma precisa manter

O código da arma (`revolver.gd` etc.) nunca toca em malhas. Ele chama `model.play_action(nome, duração, args)` e pede dois marcadores. Ao refazer um modelo, mantenha:

- os marcadores `Muzzle` e `Eject`;
- os nós animados (`_hammer`, `_cylinder`, `_lever`, `_barrels`, `_block`, `_peep`) e seus pivôs;
- as alturas de mira descritas no comentário do topo de cada modelo, que casam com `ads_position` em `weapons/data/*.tres`;
- as ações tratadas em `_play_procedural`.

## Mãos

`_hand(parent, side, curls, thumb, thumb_curl, arm, wrap)` cria uma mão fechada com antebraço e manga.

- No espaço da própria mão o punho fica na origem, os dedos apontam para -Z e fecham para -Y (lado da palma).
- `side`: 1 mão direita, -1 esquerda.
- `curls`: um trio `[nó, meio, ponta]` em radianos por dedo, do indicador ao mínimo.
- `thumb`: rotação da base do polegar; `thumb_curl` dobra a ponta (negativo dobra para o lado do dorso, que é onde fica a arma quando o polegar dá a volta nela).
- `arm`: direção em que o antebraço sai do punho, no espaço da mão.
- `wrap`: quanto a base do polegar fecha sobre a palma, em metros. Com 0 a mão está apoiada em algo; com cerca de 0,028 ela está fechada em volta de um cabo, e o "calcanhar" da mão preenche o espaço atrás dele.

O polegar sai de um músculo na base e é ligado ao nó do indicador por uma membrana; é ela que encosta na parte de trás de um cabo.

### Mão que empunha

`_grip_hand(parent, center, down, roll, size, fingers, thumb, thumb_curl, arm, wrap)` posiciona a mão direita fechada em volta de um cabo. As quatro armas usam.

- `center`: ponto no eixo do cabo que fica no meio da palma.
- `down`: direção do cabo, do indicador para o mínimo.
- `roll`: giro da mão em torno do cabo. Com 0 a palma fica chapada no lado direito e o punho atrás (revólver). Com cerca de 1,6 a palma vai para baixo e o punho sai para a direita, abaixo da linha de mira (delgado da coronha das armas longas).
- `size`: meia-largura e meia-profundidade do cabo onde os dedos passam.
- `arm` aqui é dado no espaço do pai, não no da mão.

Ela calcula onde ficam os nós dos dedos para que a primeira junta caia no canto da frente do cabo, e usa `_place_knuckles(hand, ponto, across, back)`. `GRIP_TILT` gira a palma 20° para trás do cabo, como numa empunhadura real, para o braço sair por trás da arma e não pelo lado.

### Mão de apoio

`_place_hand(hand, ponto, across, back, along)` encosta a palma em `ponto`: `across` é a direção do +X da mão e `back` é para onde o dorso aponta. `along` maior aproxima o contato dos nós dos dedos, para os dedos abraçarem peças finas. As armas longas têm a esquerda sob o guarda-mão, guardada em `_support_hand`.

No rifle de alavanca a mão direita é filha de `_grip`, um pivô na altura do cotovelo: girá-lo mantém os dedos dentro do laço enquanto a alavanca desce. Se mudar a posição da mão ou o ângulo `LEVER_OPEN`, refaça esse pivô.

### O que conferir ao mexer numa mão

- O dedo médio fica logo atrás do guarda-mato e o indicador alcança o gatilho.
- Nada da mão sobe acima da linha de mira: `ads_position` em `weapons/data/*.tres` diz onde o olho fica. Isso vale também para as pontas dos dedos da mão de apoio.
- O antebraço sai pelo canto inferior direito na visão do quadril.

### A mão que carrega

`_add_load_hand()` cria uma mão esquerda no espaço do modelo, e não no nó `Pose` que inclina na recarga, para o braço continuar vindo do lado do atirador. `_begin_loading()` faz a mão de apoio soltar a arma e mostra a mão de carga; `_animate_insert()` registra o cartucho em movimento e a mão o segue; `_end_loading()` desfaz.

## Conferir

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_windowed.ps1 res://tests/model_review.tscn
powershell -ExecutionPolicy Bypass -File tools/run_windowed.ps1 res://tests/model_review.tscn 1920x540 0
```

A primeira linha grava `output/review/models.png` com as quatro armas em quatro vistas (lado direito, frente-esquerda, visão do atirador, meio da recarga). A segunda renderiza só o revólver, maior.

Para as mãos há uma cena de perto, com seis vistas de uma arma (direita, esquerda, cima, trás, visão do quadril e visão de mira). O número escolhe a arma; `reload` ou o nome de uma ação (`lever_open`, `cock`...) congela a pose no meio do movimento:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_windowed.ps1 res://tests/hand_review.tscn 1920x1080 0
powershell -ExecutionPolicy Bypass -File tools/run_windowed.ps1 res://tests/hand_review.tscn 1920x1080 "1 lever_open"
```

`tests/ammo_review.tscn` grava `output/review/ammo.png`: o tambor do revólver por trás e pela frente (câmaras com cartucho, com estojo e vazias) e todos os cartuchos, inteiro ao lado de deflagrado. `hand_review` com `bare` esconde as mãos para ver a arma sozinha:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_windowed.ps1 res://tests/ammo_review.tscn 1920x1080
powershell -ExecutionPolicy Bypass -File tools/run_windowed.ps1 res://tests/hand_review.tscn 1920x1080 "0 bare"
```

E `tests/shot_review.tscn` captura dentro do jogo: cada arma no quadril, na mira e em quatro instantes depois do tiro (`output/review/shot_<arma>_<etapa>.png`). Aceita o número da arma e um horário (`noon`, `sunset`, `night`):

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_windowed.ps1 res://tests/shot_review.tscn 1280x720 "0 night"
```

## Limitações conhecidas

- As poses das mãos foram ajustadas por capturas paradas (quadril, mira, alavanca aberta, meio da recarga). Nenhuma foi vista em movimento por uma pessoa.
- A palma é rígida: ela não se curva em volta do cabo, e é o calcanhar da mão (`wrap`) que disfarça isso.
- No revólver o punho dobra mais do que um punho de verdade, para o antebraço não cobrir a mira.
- Na mira das armas longas a mão direita ocupa o canto inferior direito da tela. O olho fica a uns 12 cm dela; só dá para diminuir afastando `ads_position`.
- O polegar não acompanha o cão ao engatilhar.
