-- VGA signal generator
-- Outputs: - HCounter(x pos) and VCounter(y pos) 
--          - HSync and VSync
--
-- This example contains constants for:
--      640 x 480 -60Hz (25.175MHz clock)
--
-- 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity VGAGenerator is
    -- ====================== User definitons begins here  ====================== --
    --
    -- Example values taken from:
    -- tinyvga.com/vga-timing
    --
    Generic(
            constant HVisibleArea       : in natural := 640;  
            constant HFrontPorch        : in natural := 16;
            constant HSyncPulse         : in natural := 96;
            constant HBackPorch         : in natural := 48;
            
            constant VVisibleArea       : in natural := 480;  
            constant VFrontPorch        : in natural := 10;
            constant VSyncPulse         : in natural := 2;
            constant VBackPorch         : in natural := 33;
            
            -- '1' = postive  pulse polarity
            -- '0' = negative pulse polarity
            constant HSyncPulsePolarity : in STD_LOGIC := '0';
            constant VSyncPulsePolarity : in STD_LOGIC := '0' 
    );
    --
    -- Order of different signals
    -- 1. Sync pulse
    -- 2. Back porch
    -- 3. VisibleArea
    -- 4. Front Porch
    --
    --
    -- ====================== User definitons end here  ====================== --
    --
    Port (  -- Inputs
            clkIn         : in STD_LOGIC;
            -- Outputs
            VSync       : out STD_LOGIC;
            HSync       : out STD_LOGIC;
            HCounterOut : out natural;
            VCounterOut : out natural
    );
end VGAGenerator;

architecture Behavioral of VGAGenerator is 

    signal HCounter     : natural range 0 to (HVisibleArea + HFrontPorch + HSyncPulse + HBackPorch) := HVisibleArea-1;
    signal VCounter     : natural range 0 to (VVisibleArea + VFrontPorch + VSyncPulse + VBackPorch) := VVisibleArea-1;
    
    signal HS           : STD_LOGIC := not HSyncPulsePolarity;
    signal VS           : STD_LOGIC := not VSyncPulsePolarity;

begin   
        
    MainProcess : process(clkIn, HCounter, VCounter) is

    begin
        if rising_edge(clkIn) then
            HCounter    <= (HCounter +1);
            
            -- Reset HCounter when at the end of line
            if (HCounter +1) = (HVisibleArea + HFrontPorch + HSyncPulse + HBackPorch) then
                HCounter <= 0;             
            end if;
            
            if (HCounter +1) = (HVisibleArea + HFrontPorch + HSyncPulse + HBackPorch) then      
                VCounter    <= (VCounter + 1);
                
                -- Reset VCounter when at the end of row
                if (VCounter + 1) = (VVisibleArea + VFrontPorch + VSyncPulse + VBackPorch) then
                    VCounter <= 0;
                end if;
                
                -- Set VSync
                -- Only at the Sync pulse portion will VSync be at its polarity
                if ((VVisibleArea + VFrontPorch - 2) < VCounter) and (VCounter <= (VVisibleArea + VFrontPorch + VSyncPulse - 2)) then
                    VS <= VSyncPulsePolarity;
                else
                    VS <= not VSyncPulsePolarity;
                end if;        
            end if;   
            
            -- Set HSync
            -- Only at the Sync pulse portion will HSync be at its polarity
            if ((HVisibleArea + HFrontPorch - 2) < HCounter) and (HCounter <= (HVisibleArea + HFrontPorch + HSyncPulse - 2)) then
                HS <= HSyncPulsePolarity;
            else
                HS <= not HSyncPulsePolarity;
            end if;
                   
        end if;      
    end process;
    
    
    -- Conneting outputs
    HSync       <= HS;
    VSync       <= VS;
    HCounterOut <= HCounter;
    VCounterOut <= VCounter;
    
end Behavioral;
