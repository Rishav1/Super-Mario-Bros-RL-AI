BoxRadius=6
player1 = 1
TIMEOUT=100
TIMEOUT_AIR=200
EPSILON=0.5
INF_RUNS=10000

function set_imports()
  print(_VERSION)
  require("torch")
end

function set_state ()
  while(memory.readbyte(0x0772)~=0x03 or memory.readbyte(0x0770)~=0x01) do
    -- set_level(01,01)
    emu.frameadvance()
  end
  level_start = savestate.object(1)
  savestate.save(level_start)
  emu.frameadvance()
end

function set_values()
  Returns={}
  Policy={}
end


function set_level(world,level)
  memory.writebyte(0x75F,world)
  memory.writebyte(0x75C,level)
  memory.writebyte(0x760,level)
end

function init ()
  set_imports()
  set_state()
  set_values()
  emu.speedmode("maximum")
end

function getPositions()
  marioX = memory.readbyte(0x6D) * 0x100 + memory.readbyte( 0x86 )
  marioY = memory.readbyte(0x03B8)+16
  screenX = memory.readbyte(0x03AD)
  screenY = memory.readbyte(0x03B8)
end

function getTile(dx, dy)
  local x = marioX + dx + 8
  local y = marioY + dy - 16
  local page = math.floor(x/256)%2

  local subx = math.floor((x%256)/16)
  local suby = math.floor((y - 32)/16)
  local addr = 0x500 + page*13*16+suby*16+subx

  if suby >= 13 or suby < 0 then
          return 0
  end

  if memory.readbyte(addr) ~= 0 then
          return 1
  else
          return 0
  end
end

function getHashReturns(Inputs, Action)
  return getHashPolicy(Inputs)*math.pow(2,6)+Action
end

function getHashPolicy(Inputs)
  local I_value=0
  for i=1,#Inputs do
    I_value=I_value*3
    if Inputs[i]==0 then
      I_value=I_value+0
    elseif Inputs[i]==1 then
      I_value=I_value+1
    else
      I_value=I_value+2
    end
  end
  return I_value
end

function getButtonsForAction(Action)
  local action_hash=Action
  local buttons = {["A"]=false,["B"]=false,["up"]=false,["down"]=false,["left"]=false,["right"]=false}
  if action_hash%2==1 then
    buttons["right"]=true
    -- io.write("buttons[\"right\"]=true  ")
  else
    buttons["right"]=false
    -- io.write("buttons[\"right\"]=false  ")
  end
  action_hash=math.floor(action_hash/2)
  if action_hash%2==1 then
    buttons["left"]=true
    -- io.write("buttons[\"left\"]=true  ")
  else
    buttons["left"]=false
    -- io.write("buttons[\"left\"]=false  ")
  end
  action_hash=math.floor(action_hash/2)
  if action_hash%2==1 then
    buttons["down"]=true
    -- io.write("buttons[\"down\"]=true  ")
  else
    buttons["down"]=false
    -- io.write("buttons[\"down\"]=false  ")
  end
  action_hash=math.floor(action_hash/2)
  if action_hash%2==1 then
    buttons["up"]=true
    -- io.write("buttons[\"up\"]=true  ")
  else
    buttons["up"]=false
    -- io.write("buttons[\"up\"]=false  ")
  end
  action_hash=math.floor(action_hash/2)
  if action_hash%2==1 then
    buttons["B"]=true
    -- io.write("buttons[\"B\"]=true  ")
  else
    buttons["B"]=false
    -- io.write("buttons[\"B\"]=false  ")
  end
  action_hash=math.floor(action_hash/2)
  if action_hash%2==1 then
    buttons["A"]=true
    -- io.write("buttons[\"A\"]=true  ")
  else
    buttons["A"]=false
    -- io.write("buttons[\"A\"]=false  \n")
  end
  action_hash=math.floor(action_hash/2)
  if not action_hash==0 then
    eum.message("error, set button for hash didn't receive correct value\n")
  end
  return buttons
end


function getSprites()
  local sprites = {}
  for slot = 0,4 do
    local enemy = memory.readbyte( 0xF+slot)
    if enemy ~= 0 then
      local ex = memory.readbyte( 0x6E + tonumber(slot))* 0x100 + memory.readbyte( 0x87 + tonumber(slot))
      local ey = memory.readbyte( 0xCF + slot) + 24
      sprites[#sprites+1] = {["x"]=ex,["y"]=ey}
    end
  end
  return sprites
end

function getInputs()
  getPositions()
  sprites = getSprites()
  local inputs = {}

  for dy=-BoxRadius*16,BoxRadius*16,16 do
    for dx=-BoxRadius*16,BoxRadius*16,16 do
      inputs[#inputs+1] = 0

      tile = getTile(dx, dy)
      if tile == 1 and marioY+dy < 0x1B0 then
        inputs[#inputs] = 1
      end

      for i = 1,#sprites do
        distx = math.abs(sprites[i]["x"] - (marioX+dx))
        disty = math.abs(sprites[i]["y"] - (marioY+dy))
        if distx <= 8 and disty <= 8 then
          inputs[#inputs] = -1
        end
      end
    end
  end
  -- print(inputs)
  return inputs
end

function printInput()
  -- os.execute("clear")
  Input=getInputs()
  i=1
  box_print=""
  for dy=-BoxRadius*16,BoxRadius*16,16 do
    for dx=-BoxRadius*16,BoxRadius*16,16 do
      box_print=box_print.." "..Input[i]
      i=i+1
    end
    box_print=box_print.."\n"
  end
  print(box_print)
end

function printPolicy(Policy_single)
  if Policy_single==nil then
    print("policy nil")
  else
    for i=1,#Policy_single do
      print("Policy for action "..i.." is "..Policy_single[i])
    end
  end
end

function generateAction(Inputs)
  local action_taken
  if Policy[getHashPolicy(Inputs)]==nil then
    action_taken=torch.multinomial(torch.ones(1,math.pow(2,6)),1)
    action_taken=action_taken[1][1]
  else
    -- emu.message("found for "..getHashPolicy(Inputs))
    -- printPolicy(Policy[getHashPolicy(Inputs)])
    action_taken=torch.multinomial(torch.Tensor(Policy[getHashPolicy(Inputs)]),1)
    action_taken=action_taken[1]
  end
  -- printInput(Inputs)
  return action_taken-1
end

function isInAir()
  if memory.readbyte(0x001D) ~= 0x00 then
    -- print("in_air")
    return true
  else 
    return false 
  end
end


function isDead ()
  if memory.readbyte(0x000E) == 0x0B or memory.readbyte(0x000E) == 0x06 then
    return true;
  else
    return false;
  end
end

function run_episode()
  local memory={}
  local state = {}
  local long_idle=false
  while true do
    long_idle=false
    state=getInputs()
    local action_for_state=generateAction(state)
    joypad.set(player1,getButtonsForAction(action_for_state))
    memory[#memory+1]={state,action_for_state}
    if isDead() then
      emu.message("Dead")
      break
    end
    emu.frameadvance()
    local timeout=TIMEOUT
    local timeout_air=TIMEOUT_AIR

    while(getHashPolicy(getInputs())==getHashPolicy(state)) do
      joypad.set(player1,getButtonsForAction(action_for_state))
      emu.frameadvance()
      if timeout==0 then
        long_idle=true
        break
      end
      timeout = timeout-1
    end
    while(isInAir()) do
      joypad.set(player1,getButtonsForAction(action_for_state))
      emu.frameadvance()
      if timeout_air==0 then
        long_idle=true
        break
      end
      timeout_air = timeout_air-1
    end
    if long_idle then
      emu.message("Killed Due to timeout")
      break
    end
  end
  return memory
end

function getReward()
  local time_left=memory.readbyte(0x07F8)*100 + memory.readbyte(0x07F9)*10 + memory.readbyte(0x07FA)
  local dist = marioX
  return time_left+dist
end

function getReturnsForPair(Inputs,Action)
  if Returns[getHashReturns(Inputs,Action)]==nil then
    return 0
  else
    return Returns[getHashReturns(Inputs,Action)][1]
  end
end

function start_training()
  local Policy_number=1
  while true do
    print("Policy is "..Policy_number)
    Policy_number=Policy_number+1
    Returns={}
    for i=1,INF_RUNS do
      run_memory=run_episode()
      emu.message("Reward->"..getReward())
      emu.message("memory size->"..#run_memory)
      run_reward=getReward()
      for i=1,#run_memory do
        local hashed_pair=getHashReturns(run_memory[i][1],run_memory[i][2])
        if Returns[hashed_pair]==nil then
          Returns[hashed_pair]={run_reward,1}
        else
          Returns[hashed_pair][1]=(Returns[hashed_pair][1]+run_reward)/(Returns[hashed_pair][2] + 1)
          Returns[hashed_pair][2]=Returns[hashed_pair][2] + 1
        end
      end
      savestate.load(level_start)
      emu.frameadvance()
    end

    local max=-1
    local optimal_action=-1

    for i=1,#run_memory do
      
      if Policy[getHashPolicy(run_memory[i][1])]==nil then
        Policy[getHashPolicy(run_memory[i][1])]={}
      end
      
      for j=0,63 do
        if getReturnsForPair(run_memory[i][1],j) > max then
          max=getReturnsForPair(run_memory[i][1],j)
          optimal_action=j
        end
      end
      
      -- emu.message("optimal Action "..optimal_action.." for hash "..getHashPolicy(run_memory[i][1]))
      
      for j=0,63 do
        if j==optimal_action then
          Policy[getHashPolicy(run_memory[i][1])][j+1]= 1 - EPSILON + EPSILON/64
        else
          Policy[getHashPolicy(run_memory[i][1])][j+1]= EPSILON/64
        end
      end
    end
  end
end


init()
-- run_episode()
start_training()
-- while true do
--   emu.frameadvance()
--   print(type(getHashReturns(getInputs(),generateAction(getInputs())[1][1])))
-- end

  -- printInput()
  -- getPositions()
  -- emu.message("X = " .. marioX ..", Y = " .. marioY)
  -- if dead() then
  --   emu.message("Dead")
  --   savestate.load(level_start)
  -- end
  -- emu.frameadvance()
