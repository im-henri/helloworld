

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity VGA_graphics is
    Generic(
        -- ==== VGA Signal generator constants ==== --
        -- More info in VGAGenerator.vhd
        constant HVisibleArea       : in natural := 640;  
        constant HFrontPorch        : in natural := 16;
        constant HSyncPulse         : in natural := 96;
        constant HBackPorch         : in natural := 48;
        
        constant VVisibleArea       : in natural := 480;  
        constant VFrontPorch        : in natural := 10;
        constant VSyncPulse         : in natural := 2;
        constant VBackPorch         : in natural := 33;
        
        constant HSyncPulsePolarity : in STD_LOGIC := '0';
        constant VSyncPulsePolarity : in STD_LOGIC := '0'
    );
    Port ( 
        fpga_clk  : in  STD_LOGIC;
        cpu_clk   : in  STD_LOGIC; -- Note: This can be fpga_clk for now
        
        -- Should we flip i.e., copy rgb_buffer to vga_buffer.
        -- Also if flipping, destructive read simply clears rgb_buffer when requested.
        -- 'Non-destructive flipping' might be useful if say we have something on screen,
        -- while background has not changed. Clearing that something from code can be more efficient
        -- than redrawing the whole screen from scratch.
        flip_req             : in  STD_LOGIC; -- MUST BE PULSE
        destructive_read_req : in  STD_LOGIC; -- flip and clear rgb_buff
        
        fifo_w_en   : in  STD_LOGIC;
        fifo_din    : in  STD_LOGIC_VECTOR(19 DOWNTO 0); -- ADDR & VAL (Address + color, to push to rgb_buff)
        
        -- Outputs
        flip_in_progress  : out STD_LOGIC; -- is flipping in progress i.e., are we copying rgb-buff to vga_buff
        
        -- Outputs (to actual fpga pin-outs)
        colors_out  : out STD_LOGIC_VECTOR(2 downto 0) := (others => '0');
        HSync_out   : out STD_LOGIC;
        VSync_out   : out STD_LOGIC
    );
end VGA_graphics;

architecture Behavioral of VGA_graphics is
    
    component VGAGenerator is
    Generic(
            constant HVisibleArea       : in natural; 
            constant HFrontPorch        : in natural;
            constant HSyncPulse         : in natural;
            constant HBackPorch         : in natural;                                                   
            constant VVisibleArea       : in natural; 
            constant VFrontPorch        : in natural;
            constant VSyncPulse         : in natural;
            constant VBackPorch         : in natural;
            constant HSyncPulsePolarity : in STD_LOGIC;
            constant VSyncPulsePolarity : in STD_LOGIC
    );
    Port (  -- Inputs
            clkIn       : in STD_LOGIC;
            -- Outputs
            VSync       : out STD_LOGIC;
            HSync       : out STD_LOGIC;
            HCounterOut : out natural;
            VCounterOut : out natural
    );
    end component;

    component imageGeneratorVGA is
    Generic (
            constant H_VISIBLE_AREA   : natural := HVisibleArea;
            constant V_VISIBLE_AREA   : natural := VVisibleArea;
            constant pixel_ADDR_WIDTH : natural := 17
    );
    Port (  -- Inputs
            clk : in STD_LOGIC;
            
            HSync : in STD_LOGIC;
            VSync : in STD_LOGIC;
            
            HCounter : in natural;
            VCounter  : in natural;
            
            -- Output from R-, G-, B- Block Ram memories
            rBufferData : in STD_LOGIC;
            gBufferData : in STD_LOGIC;
            bBufferData : in STD_LOGIC;
            -- To R-, G-, B- Block Ram memories
            pixelAddr   : out STD_LOGIC_VECTOR(16 downto 0);
            
            -- Outputs
            color_out   : out STD_LOGIC_VECTOR(2 downto 0)

    );
    end component;
    
    -- 76800 (320x240 [QVGA]) individually adressable bits
    component blk_mem_ColorData_readfirst IS
    Port (
            -- CPU accessed side
            clka   : IN  STD_LOGIC;
            wea    : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra  : IN  STD_LOGIC_VECTOR(16 DOWNTO 0);
            dina   : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
            douta  : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
            
            -- VGA accessed side
            clkb   : IN  STD_LOGIC;
            web    : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
            addrb  : IN  STD_LOGIC_VECTOR(16 DOWNTO 0);
            dinb   : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
            doutb  : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    end component;
    
    component blk_mem_VGA_writefirst IS
    Port (
            clka   : IN  STD_LOGIC;
            wea    : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra  : IN  STD_LOGIC_VECTOR(16 DOWNTO 0);
            dina   : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
            douta  : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    end component;
    
    component FIFO_write_queue IS
    Port (
            clk    : IN  STD_LOGIC;
            srst   : IN  STD_LOGIC;
            din    : IN  STD_LOGIC_VECTOR(19 DOWNTO 0);
            
            wr_en  : IN  STD_LOGIC;
            rd_en  : IN  STD_LOGIC;
            
            dout   : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
            full   : OUT STD_LOGIC;
            empty  : OUT STD_LOGIC
    );
    end component;
    
    -- VGA Clock generator
    component clk_wiz_0
    port(   -- Clock in ports
            -- Clock out ports
            clk_out25mhz    : out    std_logic;
            clk             : in     std_logic
     );
    end component;
  
    
    signal VGA_clk   : STD_LOGIC;
    
    signal HCounter_temp_in : natural; -- Current x-position (Note: goes over the  x pixel count (as it should))
    signal VCounter_temp_in : natural; -- Current y-position (Note: goes over the y pixel count (as it should))

    signal HS_temp : STD_LOGIC;
    signal VS_temp : STD_LOGIC; 
    
    -- Wen_VGA 
    -- Goes into the dualport ram's VGA side, and VGA_buff.
    --   + As Dual-port RAM is read first and VGA_buff write first,
    --   + the data read from dual-port ram gets read into vga_buff and 
    --   + (possibly) zeroed (when requested).
    signal rgb_buff_Wen_VGA      : STD_LOGIC; 
    
    signal VGA_pixelAddr_temp     : STD_LOGIC_VECTOR(16 DOWNTO 0); -- VGA_buff addr
    signal r_buff_to_vgabuff_temp : STD_LOGIC;
    signal g_buff_to_vgabuff_temp : STD_LOGIC;
    signal b_buff_to_vgabuff_temp : STD_LOGIC;
    
    
    -- Connects VGA_buffer rgb-dout to imageGeneratorVGA
    signal r_VGA_temp  : STD_LOGIC;
    signal g_VGA_temp  : STD_LOGIC;
    signal b_VGA_temp  : STD_LOGIC;
    
    signal fifo_empty  : STD_LOGIC;
    signal fifo_full   : STD_LOGIC; -- most likely un-used
    --signal fifo_din    : STD_LOGIC_VECTOR(19 DOWNTO 0);
    signal fifo_dout   : STD_LOGIC_VECTOR(19 DOWNTO 0);
    --signal fifo_w_en   : STD_LOGIC; DEFINED ABOVE
     
    signal fifo_r_en       : STD_LOGIC; -- Oops: SAME AS BELOW
    signal rgb_buff_we_CPU : STD_LOGIC; -- Oops: SAME AS ABOVE 
    
    signal flipping        : STD_LOGIC := '0'; -- is flipping in progress i.e., are we copying rgb-buff to vga_buff

    signal UNUSED_CPU_read_color : STD_LOGIC_VECTOR(2 downto 0); -- TODO: Basically un-used but cant use 'open' for blk_mem
    
    
   TYPE VGA_SIDE_STATE IS (s0_wait_flip_req, s1_init_flip, s2_flipping);
   SIGNAL vga_state   : VGA_SIDE_STATE;
   
   
   signal destructive_read_buffered : STD_LOGIC := '0';
   
begin
    
    CPU_side_signals_process : process(cpu_clk, fifo_w_en, fifo_empty, flipping) is
    begin
        if rising_edge(cpu_clk) then
            -- Pushing to fifo
            -- No need for any extra logic
            -- 
            -- Poping from fifo
            if fifo_empty = '0' then
                -- Check if we can write it right now
                if flipping = '0' then
                    -- Perform the actual write
                    fifo_r_en       <= '1'; -- POP()
                    rgb_buff_we_CPU <= '1'; -- must make sure in 'code' that flipping is not called while writing to fifo
                else
                    fifo_r_en       <= '0';
                    rgb_buff_we_CPU <= '0';
                end if;
            else 
                -- If fifo is empty stop reading
                fifo_r_en       <= '0';
                rgb_buff_we_CPU <= '0';
            end if;
        end if;
    end process;

    
    VGA_side_signals_process : process(VGA_clk, flip_req, vga_state, destructive_read_req, VCounter_temp_in, HCounter_temp_in) is
        
        --variable hcounter_vector_temp : STD_LOGIC_VECTOR(3 downto 0);
        
    begin
        if rising_edge(VGA_clk) then
            case vga_state is
                when s0_wait_flip_req => -- FLIP REQUEST
                    if flip_req       = '1' then        vga_state <= s1_init_flip;
                        destructive_read_buffered <= destructive_read_req;
                    else                                vga_state <= s0_wait_flip_req;
                    end if;
                when s1_init_flip => -- INITIALIZE FLIP
                    if VCounter_temp_in = 0 and HCounter_temp_in = 0 then     
                                                        vga_state <= s2_flipping;
                        flipping <= '1';
                        if destructive_read_buffered = '1' then
                            rgb_buff_Wen_VGA <= '1'; -- Write zeros to rgb_buff as we are reading it                            
                        else
                            rgb_buff_Wen_VGA <= '0'; -- Dont write when to rgb_buff while reading it
                        end if;
                    else                                vga_state <= s1_init_flip;
                    end if;
                    
                when s2_flipping => -- FLIPPING
                    
                    
                    -- Eventhough, visible are is reduced to half 
                    -- VGA signals are created still as if output was 640 x 480
                    --  actually rendered is 320 x 240 but its done simply by rendering a line twice.
                    --
                    -- TLDR: HCounter counts till 480-1 not till 240-1
                    -- Note: HCounter from 0 to HVisibleArea is actual displayable area
                    --       but HCounter keeps counting over this as there is back and front borch.
                    if VCounter_temp_in > VVisibleArea-1 then
                                                        vga_state <= s0_wait_flip_req;
                        flipping <= '0';
                        rgb_buff_Wen_VGA <= '0';
                    else                                
                                                        vga_state <= s2_flipping;
                        
                        if destructive_read_buffered = '1' then
                            -- Write zeros only every second row (y)
                            if VCounter_temp_in mod 2 = 1 then
                                -- Write zeros only every second column (x)
                                if HCounter_temp_in mod 2 = 1 then
                                    -- When destructive read is initiated, we must make sure that only at the second read of the same pixel
                                    -- we perform the overwrite, as otherwize we read that second zero back into VGA buffer.
                                    -- Essentially screen sees only every other pixel and only for one frame (1/60th of second)
                                    rgb_buff_Wen_VGA <= '1';
                                else
                                    rgb_buff_Wen_VGA <= '0';
                                end if; 
                            else
                                rgb_buff_Wen_VGA <= '0';
                            end if;    
                        end if;
                                            
                    end if;
                
            end case;
        end if;
    end process;
    
    r_buffer : blk_mem_ColorData_readfirst
    Port map (
            -- CPU accessed side
            clka     => cpu_clk,
            wea(0)   => rgb_buff_we_CPU,
            addra    => fifo_dout(19 downto 3),
            dina(0)  => fifo_dout(2),
            douta(0) => UNUSED_CPU_read_color(2),
            
            -- VGA accessed side
            clkb     => VGA_clk,
            web(0)   => rgb_buff_Wen_VGA,
            addrb    => VGA_pixelAddr_temp,
            dinb(0)  => '0',                        -- For destructive reading
            doutb(0) => r_buff_to_vgabuff_temp
    );
    -- WRITE FIRST buffer
    r_VGA_buff :  blk_mem_VGA_writefirst
    Port map (
            -- Inputs
            clka     => VGA_clk,
            wea(0)   => flipping,
            addra    => VGA_pixelAddr_temp,
            dina(0)  => r_buff_to_vgabuff_temp,
            -- Outputs
            douta(0) => r_VGA_temp
    );
    
    g_buffer : blk_mem_ColorData_readfirst
    Port map (
            -- CPU accessed side
            clka     => cpu_clk,
            wea(0)   => rgb_buff_we_CPU,
            addra    => fifo_dout(19 downto 3),
            dina(0)  => fifo_dout(1),
            douta(0) => UNUSED_CPU_read_color(1),
            
            -- VGA accessed side
            clkb     => VGA_clk,
            web(0)   => rgb_buff_Wen_VGA,
            addrb    => VGA_pixelAddr_temp,
            dinb(0)  => '0',                        -- For destructive reading
            doutb(0) => g_buff_to_vgabuff_temp
    );
    -- WRITE FIRST buffer
    g_VGA_buff :  blk_mem_VGA_writefirst
    Port map (
            -- Inputs
            clka     => VGA_clk,
            wea(0)   => flipping,
            addra    => VGA_pixelAddr_temp,
            dina(0)  => g_buff_to_vgabuff_temp,
            -- Outputs
            douta(0) => g_VGA_temp
    );
    
    b_buffer : blk_mem_ColorData_readfirst
    Port map (
            -- CPU accessed side
            clka     => cpu_clk,
            wea(0)   => rgb_buff_we_CPU,
            addra    => fifo_dout(19 downto 3),
            dina(0)  => fifo_dout(0),
            douta(0) => UNUSED_CPU_read_color(0),
            
            -- VGA accessed side
            clkb     => VGA_clk,
            web(0)   => rgb_buff_Wen_VGA,
            addrb    => VGA_pixelAddr_temp,
            dinb(0)  => '0',                        -- For destructive reading
            doutb(0) => b_buff_to_vgabuff_temp
    );
    -- WRITE FIRST buffer
    b_VGA_buff :  blk_mem_VGA_writefirst
    Port map (
            -- Inputs
            clka     => VGA_clk,
            wea(0)   => flipping,
            addra    => VGA_pixelAddr_temp,
            dina(0)  => b_buff_to_vgabuff_temp,
            -- Outputs
            douta(0) => b_VGA_temp
    );
     

    write_queue : FIFO_write_queue
    Port map (
            -- Inputs
            clk    => cpu_clk,
            srst   => '0',       -- Note: Reset currently disabled (no use)
            din    => fifo_din,
            wr_en  => fifo_w_en,
            rd_en  => fifo_r_en,
            -- Outputs
            dout   => fifo_dout,
            full   => fifo_full,
            empty  => fifo_empty
    );
    
    -- VGA related stuff
    --
    generated_clock_25mhz : clk_wiz_0
    port map ( 
           -- Out ports  
           clk_out25mhz => VGA_clk,
           -- In ports
           clk          => fpga_clk
    );
    
    VGA_sync_signals : VGAGenerator
    generic map (
        HVisibleArea       => HVisibleArea, 
        HFrontPorch        => HFrontPorch,
        HSyncPulse         => HSyncPulse,
        HBackPorch         => HBackPorch,                                                   
        VVisibleArea       => VVisibleArea, 
        VFrontPorch        => VFrontPorch,
        VSyncPulse         => VSyncPulse,
        VBackPorch         => VBackPorch,
        HSyncPulsePolarity => HSyncPulsePolarity,
        VSyncPulsePolarity => VSyncPulsePolarity
    )
    port map ( 
        clkIn       => VGA_clk,

        -- Outputs  
        VSync       => VS_temp,
        HSync       => HS_temp,
        HCounterOut => HCounter_temp_in,
        VCounterOut => VCounter_temp_in
    );
    
    VGA_image_signals : imageGeneratorVGA
    Generic map (
            H_VISIBLE_AREA   => HVisibleArea,
            V_VISIBLE_AREA   => VVisibleArea,
            pixel_ADDR_WIDTH => 17     
    )
    Port map (  -- Inputs
            clk      => VGA_clk,
           
            HSync    => HS_temp,
            VSync    => VS_temp,
           
            HCounter => HCounter_temp_in,
            VCounter => VCounter_temp_in,
            
            -- Output from R-, G-, B- Block Ram memories
            rBufferData => r_VGA_temp,
            gBufferData => g_VGA_temp,
            bBufferData => b_VGA_temp,
            
            -- To R-, G-, B- Block Ram memories
            pixelAddr   => VGA_pixelAddr_temp,
            
            -- Outputs
            color_out   => colors_out
    );

    flip_in_progress <= flipping;
    
    HSync_out <= HS_temp;
    VSync_out <= VS_temp;


end Behavioral;
