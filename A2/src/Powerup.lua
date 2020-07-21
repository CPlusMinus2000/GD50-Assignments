--[[
    GD50
    Breakout Remake

    -- Powerup Class --

    Author: Colin He
    hcolin88@gmail.com

    Represents a powerup, which appears randomly whenever a brick is
    damaged. When collected, i.e. upon making contact with the paddle,
    the powerup spans two additional balls into the game.
]]

Powerup = Class{}

function Powerup:init(skin)
    -- simple positional and dimensional variables
    self.width = 16
    self.height = 16

    -- descension speed
    self.dy = 30

    -- this will be the type of the powerup, and we will index
    -- our table of Quads relating to the global block texture using this
    self.skin = skin

    -- removal boolean
    self.remove = false
end

--[[
    Expects an argument with a bounding box, be that a paddle or a brick,
    and returns true if the bounding boxes of this and the argument overlap.
]]
function Powerup:collides(target)
    -- first, check to see if the left edge of either is farther to the right
    -- than the right edge of the other
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    -- then check to see if the bottom edge of either is higher than the top
    -- edge of the other
    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end 

    -- if the above aren't true, they're overlapping
    return true
end

--[[
    Places the powerup in the middle of the screen, with no movement.
]]
function Powerup:reset()
    self.x = VIRTUAL_WIDTH / 2 - 4
    self.y = VIRTUAL_HEIGHT / 2 - 4
    self.dx = 0
    self.dy = 0
    self.remove = false
end

--[[
    Update function
]]
function Powerup:update(dt)
    self.y = self.y + self.dy * dt
end

function Powerup:render()
    -- gTexture is our global texture for all blocks
    -- gBallFrames is a table of quads mapping to each individual ball skin in the texture
    love.graphics.draw(gTextures['main'], gFrames['powerups'][self.skin],
        self.x, self.y)
end