# Dead Eye Range

FPS western de precisão em Godot 4.7.2, GDScript. Um jogador, alvos mecânicos; ninguém atira de volta. Toda a geometria é construída em código, os efeitos sonoros são sintetizados e a música é composta em MIDI e renderizada com FluidSynth. Não há addons.

## Jogar

Abra `project.godot` no Godot e pressione **F5**, ou rode na pasta do projeto:

```powershell
Godot_v4.7.2-stable_win64_console.exe --path .
```

O menu oferece quatro modos. F1–F4 também trocam de modo durante o jogo, e Enter reinicia uma partida terminada.

| Modo | O que é |
|---|---|
| Free Range | Todas as armas e todos os alvos, sem relógio. Nada é salvo. |
| Gallery | 90 segundos de garrafas, bandidos, rodas e pratos. Pontuação por combo, estilo e truques. |
| Quick Draw | Cinco duelos: guarde a arma, espere o sino, saque. Avaliado pelo tempo médio de reação. |
| Long Shot | O Sharps de 100 a 500 m, dois acertos por distância, vento mudando a cada etapa, 240 s. |

Controles padrão (todos remapeáveis em Settings → Controls):

| Controle | Ação |
|---|---|
| WASD / analógico esquerdo | Mover |
| Mouse / analógico direito | Olhar |
| Shift / Ctrl | Correr / agachar |
| LMB | Disparar |
| RMB | Mirar; também trabalha a ação (engatilhar, alavanca) |
| F | Trabalhar a ação |
| Alt + LMB | Fanning do revólver / dois canos da coach gun |
| R | Recarregar; R ou disparo interrompe após a etapa atual |
| 1–4 / roda | Trocar de arma |
| H | Guardar / sacar |
| Q / E, ou roda mirando | Ajustar a mira do rifle |
| V | Dead Eye: ativar, depois soltar as marcas |
| Esc | Pausa (congela física, relógios e câmera lenta) |

**Dead Eye** carrega 25% a cada bullseye, headshot ou acerto em alvo no ar. Cheio, dá quatro segundos reais de câmera lenta para marcar até seis alvos (limitado à munição carregada); a sequência usa a ação normal da arma e gasta cartuchos. Fica desligado em Quick Draw e Long Shot.

## O que o HUD mostra

- **Canto superior esquerdo:** recompensa, combo e multiplicador, barra do tempo que resta ao combo, multiplicador de estilo.
- **Canto superior direito:** modo, relógio ou rodada, objetivo atual.
- **Canto inferior esquerdo:** a arma, o que ela precisa agora (“Cock the hammer”, “Empty”) e os cartuchos: o tambor do revólver visto por trás, câmara a câmara, ou a fileira de cartuchos das armas longas. Rifles mostram também alça de mira e vento.
- **Centro inferior:** medidor do Dead Eye. **Direita:** flâmula do vento quando a arma tem alça ajustável.
- Os pontos são carimbados onde a bala acertou. As dicas de teclas aparecem ao trocar de arma e somem depois de alguns segundos; usam as teclas que você configurou.

## Estado

Tudo abaixo está implementado e passa nos testes automáticos. O que os testes **não** cobrem está na última coluna.

| Fase | Feito | Não verificado |
|---|---|---|
| 1–3 | Controle, quatro armas, balística com queda e vento, alvos, Gallery, Quick Draw, combo/estilo/truques, salvamento | Valores de sensação e limiares de estrelas nunca foram jogados por uma pessoa |
| 4 | Tema com Rye + Bitter, HUD em etiquetas de papel, carimbos de pontuação, menu-cartaz com recordes, pausa, resultados com estrelas, configurações em quatro abas, remapeamento com restauração | Navegação só por gamepad nos menus |
| 5 | 111 arquivos em 32 chaves, sintetizados; buses Music/SFX/UI/Ambience e bus de eco; eco do tiro atrasado pela distância à parede; impactos por superfície; vento que acompanha o vento balístico; tratamento de câmera lenta | **A mixagem nunca foi ouvida.** Os sons foram conferidos por duração, nível e espectro, não de ouvido |
| 6 | Cinco temas em três camadas sincronizadas (ritmo, melodia, intensidade) e três vinhetas, renderizados com FluidSynth + GeneralUser GS; camadas seguem combo, estilo e a tensão do duelo | **A música nunca foi ouvida.** Notas, equilíbrio entre camadas e emendas de loop foram conferidos por medição |
| 7 | Rua com fachadas, igreja com campanário, moinho que gira com o vento, caixa d'água, barris, cercas, cactos, mesas ao fundo, poeira, calor, tumbleweeds; pôr do sol, meio-dia e noite estrelada; Dead Eye; Long Shot | Desempenho fora desta máquina (RTX 5060) |
| Modelos | As quatro armas refeitas com peças torneadas, coronhas arredondadas e chapas chanfradas; mãos e antebraços do jogador em todas; a mão esquerda solta a arma para carregar | As poses das mãos foram ajustadas por capturas paradas: a recarga em movimento e a mira (ADS) com as mãos não foram vistas em jogo |

## Testes

```powershell
powershell -ExecutionPolicy Bypass -File tools/check.ps1 -All       # fases 1–7
powershell -ExecutionPolicy Bypass -File tools/check.ps1 -Import    # depois de mexer em áudio ou fontes
powershell -ExecutionPolicy Bypass -File tools/check.ps1 res://tests/phase4_smoke.tscn
```

O script procura `Godot_v4*_console.exe` ou `godot` no PATH (ou use `$env:GODOT`). Ele falha se um teste falhar ou se o Godot imprimir erro de script, e usa `.runtime/` para não tocar nos seus saves. O primeiro `-Import` depois de trocar muitos arquivos de áudio pode terminar com o Godot fechando com erro; rodar de novo conclui normalmente.

Os testes rodam sem tela e sem dispositivo de áudio. Eles verificam mecânicas, pontuação, salvamento, construção dos menus, remapeamento, pausa, recursos e roteamento de áudio, estrutura e camadas da música, Dead Eye e uma bala real a 500 m. Não verificam aparência nem som.

Para olhar só os modelos das armas e as mãos de quatro ângulos há `tests/model_review.tscn` (grava `output/review/models.png`; `-- 0` a `-- 3` renderiza uma arma só). `tools/run_windowed.ps1 <cena> [resolução] [argumento]` roda uma cena com janela e limite de tempo.

Para a aparência há `tests/visual_review.tscn`, que salva capturas em `output/review/` (menu, configurações, as quatro armas, Dead Eye, noite, meio-dia, contagem, Gallery, pausa, resultados, duelo, coleção de armas):

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 res://tests/visual_review.tscn
```

## Regenerar o áudio

Os arquivos gerados estão no projeto; nada disto é necessário para jogar. Precisa de Python 3 com `numpy scipy mido soundfile`.

```powershell
python tools/sfx/generate.py      # audio/sfx/*.wav + manifest.json
python tools/music/compose.py     # audio/music/midi/*.mid + score.json
python tools/music/render.py      # audio/music/*.ogg + manifest.json
```

`render.py` procura o FluidSynth no PATH ou em `.downloads/`, e o soundfont em `.downloads/soundfont/GeneralUser-GS.sf2`; ambos podem ser passados com `--fluidsynth` e `--soundfont`. Cada camada é renderizada separadamente e a cauda de reverberação é dobrada sobre o início, o que deixa o loop sem emenda. Depois de regenerar, rode `tools/check.ps1 -Import`.

Para trocar qualquer som por uma gravação, preencha `sounds` ou `music` em `audio/default_bank.tres`: o que estiver ali vale mais que os manifests gerados.

## Organização

| Pasta | Conteúdo |
|---|---|
| `autoload/` | `Settings`, `Wind`, `GameState` (pontuação), `SaveSystem`, `AudioManager` (efeitos), `MusicDirector` (trilha) |
| `player/` | Controle em primeira pessoa e `dead_eye.gd` |
| `weapons/` | Base `weapon.gd`, uma pasta por arma, `data/*.tres` com os números, `weapon_model.gd` para os modelos |
| `targets/` | Um script por tipo de alvo sobre `target.gd` |
| `modes/` | `game_mode.gd` e os quatro modos; cada um diz ao HUD o que mostrar |
| `levels/` | `range_environment.gd`: a cidade, a luz e o céu |
| `ui/` | `frontier.gd` (paleta, fontes, tema), `hud.gd`, `menu.gd`, `settings_page.gd`, shaders |
| `audio/` | Sons, música, fontes MIDI e `sound_bank.gd` |
| `tools/` | Geradores de áudio, `check.ps1` e `run_windowed.ps1` |
| `docs/` | `MODELING.md`: como os modelos e as mãos são construídos |
| `tests/` | Um teste por fase e as capturas |

Saves ficam em `user://save.json`; preferências e teclas em `user://settings.cfg`.

## Créditos e licenças

- **Rye** (Nicole Fally) e **Bitter** (Sol Matas), via Google Fonts, SIL Open Font License 1.1. As licenças estão em `ui/fonts/`.
- **GeneralUser GS 2.0.3**, de S. Christian Collins, usado para renderizar a música. O soundfont não é distribuído no projeto, só os áudios renderizados; a licença dele permite esse uso.
- **FluidSynth** (LGPL 2.1), usado apenas como ferramenta de renderização.
- Composições, efeitos sonoros, código e modelos são originais deste projeto.
