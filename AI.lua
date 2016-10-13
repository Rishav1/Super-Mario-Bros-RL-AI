BoxRadius=6
player1 = 1
TIMEOUT=50
TIMEOUT_AIR=0
EPSILON=0.05
INF_RUNS=1

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
  return getHashPolicy(Inputs).."->"..Action
end

function getHashPolicy(Inputs)
  local I_value=""
  for i=1,#Inputs do
    I_value=Inputs[i]..I_value
  end
  return I_value
end

function getButtonsForAction(Action)
  local action_hash=Action
  b_str=""
  local buttons = {["A"]=false,["B"]=false,["up"]=false,["down"]=false,["left"]=false,["right"]=false}
  if action_hash%2==1 then
    buttons["right"]=true
    buttons["left"]=false
    -- io.write("buttons[\"right\"]=true  ")
    b_str=b_str.."right, "
  else
    buttons["right"]=false
    buttons["left"]=true
    -- io.write("buttons[\"right\"]=false  ")
    b_str=b_str.."left, "
  end
  action_hash=math.floor(action_hash/2)
  if action_hash%2==1 then
    -- buttons["down"]=true
    buttons["up"]=false
    -- io.write("buttons[\"down\"]=true  ")
    -- b_str=b_str.."down, "
  else
    -- buttons["down"]=false
    buttons["up"]=true
    -- io.write("buttons[\"down\"]=false  ")
    b_str=b_str.."up, "
  end
  action_hash=math.floor(action_hash/2)
  if action_hash%2==1 then
    buttons["B"]=true
    -- io.write("buttons[\"B\"]=true  ")
    b_str=b_str.."B, "
  else
    buttons["B"]=false
    -- io.write("buttons[\"B\"]=false  ")
  end
  action_hash=math.floor(action_hash/2)
  if action_hash%2==1 then
    buttons["A"]=true
    -- io.write("buttons[\"A\"]=true  ")
    b_str=b_str.."A, "
  else
    buttons["A"]=false
    -- io.write("buttons[\"A\"]=false  \n")
  end
  action_hash=math.floor(action_hash/2)
  if not action_hash==0 then
    eum.message("error, set button for hash didn't receive correct value\n")
  end
  -- emu.message(b_str)
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
  return inputs
end

function printInput()
  os.execute("clear")
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
  g_str=""
  if Policy[getHashPolicy(Inputs)]==nil then
    -- action_taken=torch.multinomial(torch.ones(1,12),1)  --change this to 16 for enabling both A and B simultaneous press
    -- action_taken=action_taken[1][1]
    action_taken=10
    g_str=g_str..",new "
  else
    g_str=g_str..",found "
    local x,y=torch.max(torch.Tensor(Policy[getHashPolicy(Inputs)]),1)
    -- y= y[1]-1
    -- printPolicy(Policy[getHashPolicy(Inputs)])
    -- print("Found saved action for "..getHashPolicy(Inputs).." is "..y.. " and Returns is "..getReturnsForPair(Inputs,y))  
    action_taken=torch.multinomial(torch.Tensor(Policy[getHashPolicy(Inputs)]),1)
    action_taken=action_taken[1]
    if action_taken==y[1] then
      g_str=g_str..",taken "
    else
      g_str=g_str..",not taken "
    end
  end
  action_taken= action_taken-1
  -- print("Action taken "..action_taken)
  return action_taken
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
  maxMario=nil
  local memory={}
  local state = {}
  while true do
    state=getInputs()
    local action_for_state=generateAction(state)
    joypad.set(player1,getButtonsForAction(action_for_state))
    emu.message(g_str.."--->"..b_str)
    memory[#memory+1]={state,action_for_state}
    if isDead() then
      emu.message("Dead")
      break
    end
    emu.frameadvance()
    setReward()
    local long_idle=false
    local timeout=TIMEOUT
    local timeout_air=TIMEOUT_AIR

    while(getHashPolicy(getInputs())==getHashPolicy(state)) do
      joypad.set(player1,getButtonsForAction(action_for_state))
      -- memory[#memory+1]={state,action_for_state}
      emu.frameadvance()
      setReward()
      if timeout==0 then
        long_idle=true
        break
      end
      timeout = timeout-1
    end
    while(isInAir()) do
      joypad.set(player1,getButtonsForAction(action_for_state))
      -- memory[#memory+1]={state,action_for_state}
      emu.frameadvance()
      setReward()
      if timeout_air==0 then
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

function setReward()
  local dist = marioX
  if maxMario==nil then
    maxMario=marioX
  else
    if maxMario<marioX then
      maxMario=marioX
    end
  end
end

function getReward()
  local time_left=memory.readbyte(0x07F8)*100 + memory.readbyte(0x07F9)*10 + memory.readbyte(0x07FA)
  local dist = maxMario
  return time_left*dist
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
    -- Returns={}
    for i=1,INF_RUNS do
      print("---------------------------------------------------")
      print("Policy is "..Policy_number)
      print("Run is "..i)
      run_memory=run_episode()
      print("Reward->"..getReward())
      print("memory size->"..#run_memory)
      run_reward=getReward()
      local new_states=0
      for i=1,#run_memory do
        local hashed_pair=getHashReturns(run_memory[i][1],run_memory[i][2])
        if Returns[hashed_pair]==nil then
          new_states = new_states + 1
          Returns[hashed_pair]={run_reward,1}
        else
          -- Returns[hashed_pair][1]=(Returns[hashed_pair][1]+run_reward)/(Returns[hashed_pair][2] + 1) -- For average reward as given in the book
          -- Returns[hashed_pair][2]=Returns[hashed_pair][2] + 1
          if run_reward>Returns[hashed_pair][1] then  -- For max of the observed rewards, My change to get fast results
            Returns[hashed_pair][1]=run_reward
            Returns[hashed_pair][2]=1
          end
        end
      end
      print("Number of New States is "..new_states)
      savestate.load(level_start)
    end


    for i=1,#run_memory do
      
      local max=-1
      local optimal_action=-1
      if Policy[getHashPolicy(run_memory[i][1])]==nil then
        Policy[getHashPolicy(run_memory[i][1])]={}
      end
      
      for j=0,11 do --Max value of action is 11 so that both A and B buttons are never pressed togather, Otherwise keep it 16
        if getReturnsForPair(run_memory[i][1],j) > max then
          max=getReturnsForPair(run_memory[i][1],j)
          optimal_action=j
        end
      end
      
      -- print("optimal Action "..optimal_action.." for hash "..getHashPolicy(run_memory[i][1]))
      
      for j=0,11 do
        if j==optimal_action then
          Policy[getHashPolicy(run_memory[i][1])][j+1]= 1 - EPSILON + EPSILON/11
        else
          Policy[getHashPolicy(run_memory[i][1])][j+1]= EPSILON/11
        end
      end
    end
    Policy_number=Policy_number+1
  end
end


init()
-- run_episode()
start_training()