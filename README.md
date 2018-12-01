# Super Mario Bros (NES) AI

The project is to make Reinforcement Learning based models that can learn to play super mario bros.

[![Q-Learning on Mario](https://img.youtube.com/vi/eKQA3UmfcVM/0.jpg)](https://www.youtube.com/watch?v=eKQA3UmfcVM "Q-learning agent trains on Super Mario Bros")


# Requirements

- FCEUX2.2.3 emulator (More information is available [here.](http://www.fceux.com/web/home.html))
- Lua 5.1
- Torch (can be installed from [here.](http://torch.ch/docs/getting-started.html#_))

# Running

Make sure fceux executable is in the path. Both windows and Linux versions of fceux are supported.

```
$ fceux ./Super\ Mario\ Bros.\ \(Japan,\ USA\).nes --loadlua ./AI.lua
```
