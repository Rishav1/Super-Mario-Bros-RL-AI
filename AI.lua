player1 = 1
jumping = false
buttons = {}
buttons["right"] = true
buttons["B"] = true

function set_buttons ()
  if (emu.framecount() % 50 == 0) then
    jumping = not jumping
    gui.savescreenshot()
  end;
  buttons["A"] = jumping
  joypad.set(player1, buttons)
end

function set_state ()
  level1_start = savestate.object(1)
  savestate.save(level1_start)

end

function init ()
  set_state()
end

function draw_text ()
  marioX = memory.readbyte(0x6D) * 0x100 + memory.readbyte(0x86)
  marioY = memory.readbyte(0x03B8)+16
  -- emu.message("X = " .. marioX ..", Y = " .. marioY)
end

function dead ()
  return false;
end

init()
while true do
  draw_text()
  set_buttons()
  if dead() then
    emu.message("Dead")
    savestate.load(level1_start)
  end
  emu.frameadvance()
end
