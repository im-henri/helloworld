library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use IEEE.math_real.ALL; -- for floor

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity VGA_Graphics_top is
    Port (  -- Inputs
            fpga_clk             : in STD_LOGIC; -- needed to synthesize VGA specific clk
            cpu_clk              : in STD_LOGIC;  
            
            flip_req             : in  STD_LOGIC; -- MUST BE PULSE
            destructive_read_req : in  STD_LOGIC; -- flip and clear rgb_buff
            ---
            -- VGA_REQ_FIFO content
            --      00           012345678          01234567          012345678         01234567           012
            --      2               +9                +8                 +9               +8               +3      = 39
            -- 38 downto 37     36 downto 28      27 downto 20      19 downto 11       10 downto 3      2 downto 0   
            -----------------------------------------------------------------------------------------------------------
            --     type              x0                y0                x1               y1              color
            --     type: "00" set_pixel(x0,y0, color),
            --           "01" line_draw(x0,y0,x1,y1, color)
            vga_req_fifo_din     : in  STD_LOGIC_VECTOR(38 DOWNTO 0);
            vga_req_fifo_wr_en   : in  STD_LOGIC;
           
            -- Outputs           
            flip_in_progress_out : out STD_LOGIC;
            
            Colors               : out STD_LOGIC_VECTOR(2 downto 0) := (others => '0');
            HSync                : out STD_LOGIC;
            VSync                : out STD_LOGIC
    );
end VGA_Graphics_top;

architecture Behavioral of VGA_Graphics_top is
    
    component VGA_graphics
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
    end component;
    
    component Bresenham_linedraw is
    Port (  -- Inputs
            clk         : in  STD_LOGIC;
            draw_req    : in  STD_LOGIC;
            
            -- Inputs: Line start and end position ( Do no need to persist after draw_req has been '1'. )
            x0_in       : in  STD_LOGIC_VECTOR(8 downto 0); -- Up to 512 pixels wide
            y0_in       : in  STD_LOGIC_VECTOR(7 downto 0); -- Up to 256 pixels high
            x1_in       : in  STD_LOGIC_VECTOR(8 downto 0); 
            y1_in       : in  STD_LOGIC_VECTOR(7 downto 0);
            color_in    : in  STD_LOGIC_VECTOR(2 downto 0); -- Color of the line
            
            -- Input:  Pop pixel (ADDR & COLOR) to then add into rgb_buff
            --         Only pop IF has_pixels = '1'
            pop_pixel   : in  STD_LOGIC;
            
            -- Outputs
            pixel_dout  : out STD_LOGIC_VECTOR(19 downto 0); -- ADDR & VAL (Address + color, to push to rgb_buff)
            fifo_empty  : out STD_LOGIC;
            
            line_finished   : out STD_LOGIC
    );
    end component;
        
    component LUT_mult320 IS
    Port (
            clka    : IN  STD_LOGIC;
            addra   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            douta   : OUT STD_LOGIC_VECTOR(16 DOWNTO 0)
    );
    end component;
    
    component vga_draw_request_fifo IS
    PORT (
        clk     : IN STD_LOGIC;
        din     : IN STD_LOGIC_VECTOR(38 DOWNTO 0);
        
        wr_en   : IN STD_LOGIC;
        rd_en   : IN STD_LOGIC;
        
        dout    : OUT STD_LOGIC_VECTOR(38 DOWNTO 0);
        full    : OUT STD_LOGIC;
        empty   : OUT STD_LOGIC
    );
    end component;
    
    

    --signal vga_req_fifo_din     : STD_LOGIC_VECTOR(38 DOWNTO 0);
    --signal vga_req_fifo_wr_en   : STD_LOGIC;
    
    signal vga_req_fifo_rd_en   : STD_LOGIC;
    signal vga_req_fifo_dout    : STD_LOGIC_VECTOR(38 DOWNTO 0);
    signal vga_req_fifo_full    : STD_LOGIC; -- NOTE: NOT USED ANYWHERE 
    signal vga_req_fifo_empty   : STD_LOGIC;
    
    ---
    
    signal lut_mult320_addra    : STD_LOGIC_VECTOR(7 DOWNTO 0);
    signal lut_mult320_douta    : STD_LOGIC_VECTOR(16 DOWNTO 0);
    
    ---
    
    --signal flip_req             : STD_LOGIC := '0'; -- MUST BE PULSE
    --signal destructive_read_req : STD_LOGIC := '0'; -- flip and clear rgb_buff        
    signal fifo_w_en            : STD_LOGIC := '0';
    signal fifo_din             : STD_LOGIC_VECTOR(19 DOWNTO 0) := (others => '0'); -- ADDR & VAL (Address + color, to push to rgb_buff)
    signal flip_in_progress     : STD_LOGIC := '0'; -- is flipping in progress i.e., are we copying rgb-buff to vga_buff
    

    --signal Colors   : std_logic_vector(2 downto 0) := (others => '0');
    --signal HSync  : STD_LOGIC;
    --signal VSync  : STD_LOGIC;

    
    ---

     
    signal linedraw_req    : STD_LOGIC := '0';
    
    signal linepop_pixel   : STD_LOGIC := '0';
     
    signal linepixel_dout  : STD_LOGIC_VECTOR(19 downto 0); -- ADDR & VAL (Address + color, to push to rgb_buff)
    signal linefifo_empty  : STD_LOGIC;
    
    signal line_finished  : STD_LOGIC;
    
    signal line_draw_pixels_copied : STD_LOGIC := '0'; -- all pixels from line draw fifo copied over to rgb-buff
    ---
    
    type vga_draw_state_type is (s0_idle, s1_fetch, s2_process, 
                                    s_pixel_draw, 
                                    s_line_draw_init, s_line_draw
                                 );
    signal vga_draw_state : vga_draw_state_type := s0_idle;
    
begin
    
    flip_in_progress_out <= flip_in_progress;
    
    ---------
    
    VGA_double_buffered : VGA_graphics
    Port map ( 
        fpga_clk  => fpga_clk,
        cpu_clk   => cpu_clk,
        
        flip_req             => flip_req,
        destructive_read_req => destructive_read_req,
        
        fifo_w_en   => fifo_w_en,
        fifo_din    => fifo_din,
        
        -- Outputs
        flip_in_progress  => flip_in_progress, -- is flipping in progress i.e., are we copying rgb-buff to vga_buff
        
        -- Outputs (to actual fpga pin-outs)
        colors_out  => Colors,
        HSync_out   => HSync,
        VSync_out   => VSync
    );
    
    linedrawer : Bresenham_linedraw
    Port map(
            clk         => cpu_clk,
            draw_req    => linedraw_req,
            
            -- Inputs: Line start and end position ( Do no need to persist after draw_req has been '1'. )
            x0_in       => vga_req_fifo_dout(36 downto 28),  -- x0
            y0_in       => vga_req_fifo_dout(27 downto 20),  -- y0
            x1_in       => vga_req_fifo_dout(19 downto 11),  -- x1
            y1_in       => vga_req_fifo_dout(10 downto 3),   -- y1
            color_in    => vga_req_fifo_dout(2 downto 0),    -- color
            
            -- Input:  Pop pixel (ADDR & COLOR) to then add into rgb_buff
            --         Only pop IF has_pixels = '1'
            pop_pixel   => linepop_pixel,
            
            -- Outputs
            pixel_dout  => linepixel_dout,
            fifo_empty  => linefifo_empty,
            
            line_finished => line_finished
    );
    
    
    vga_draw_request_queue : vga_draw_request_fifo
    port map(
            clk     => cpu_clk,
            din     => vga_req_fifo_din,
            
            wr_en   => vga_req_fifo_wr_en,
            rd_en   => vga_req_fifo_rd_en,
            
            dout    => vga_req_fifo_dout,
            full    => vga_req_fifo_full,
            empty   => vga_req_fifo_empty
    );
    
    mult_y0_320 : LUT_mult320
    Port map (
            clka    => cpu_clk,
            addra   => vga_req_fifo_dout(27 downto 20), -- 27 downto 20 = y0
            douta   => lut_mult320_douta
    );
    
    -- 
    vga_state_using : process(cpu_clk, vga_draw_state, line_finished, linefifo_empty) is
        variable pix_addr   : STD_LOGIC_VECTOR(16 DOWNTO 0);  -- to improve readability
        variable pix_color  : STD_LOGIC_VECTOR(2 downto 0);   -- to improve readability
    begin
        if rising_edge(cpu_clk) then
            case vga_draw_state is
                
                ----------- Before drawing ----------
                
                when s0_idle =>
                    -- NOTE: Writing to vga_req_fifo_rd_en below
                    fifo_w_en <= '0';
                    line_draw_pixels_copied <= '0';
                
                when s1_fetch =>
                    fifo_w_en <= '0';
                    line_draw_pixels_copied <= '0';
                    
                when s2_process => 
                    fifo_w_en <= '0';
                    line_draw_pixels_copied <= '0';
                    
                ----- Set Pixel / Pixel Drawing -----
                
                when s_pixel_draw =>
                    --
                    pix_addr  := std_logic_vector(unsigned(lut_mult320_douta) + unsigned(vga_req_fifo_dout(36 downto 28))); 
                    pix_color := vga_req_fifo_dout(2 downto 0);
                    
                    fifo_din  <= pix_addr & pix_color; -- ADDR & VAL (Address + color, to push to rgb_buff)
                    fifo_w_en <= '1';
                
                -----------  Line Drawing -----------
                
                when s_line_draw_init =>
                    linedraw_req <= '1'; -- must be pulse
                
                when s_line_draw => 
                    linedraw_req <= '0'; -- must be pulse
                    
                    if linefifo_empty = '0' then
                        linepop_pixel <= '1';
                        fifo_w_en     <= '1';
                    else
                        linepop_pixel <= '0';
                        fifo_w_en     <= '0';
                    end if;
                    
                    if (linefifo_empty = '1' and line_finished = '1') then
                        line_draw_pixels_copied <= '1';
                    else
                        line_draw_pixels_copied <= '0';
                    end if;
                    
                    -- WARNING: TODO: Might need another stage to delay fifo_w_en
                    -- as linepixel_dout might not be ready when fifo_din needs it
                    --     -> RGB-buff might miss first pixel
                    fifo_din <= linepixel_dout;
                    
                
                when others => 
                    -- Do nothing
                    
            end case;
        end if;
    end process;
    
    -- Only state switching is here
    -- NOTE: Changing vga_req_fifo_rd_en (makes more sense to copy paste same if statement to above) 
    vga_state_switching : process(cpu_clk, vga_draw_state, vga_req_fifo_empty, line_finished, line_draw_pixels_copied, flip_in_progress) is
    begin
        if rising_edge(cpu_clk) then
            case vga_draw_state is
                when s0_idle =>
                
                    -- Dont allow any drawing when flip_in_progress
                    -- Note that pushing to vga_req_fifo is still allowed,
                    -- just that none of the requests will be processed.
                    if (vga_req_fifo_empty = '0') and (flip_in_progress = '0') then
                        vga_draw_state      <= s1_fetch;      
                        vga_req_fifo_rd_en  <= '1';             
                    else
                        vga_draw_state <= s0_idle;
                        vga_req_fifo_rd_en <= '0';
                    end if;
                   
                when s1_fetch =>
                    vga_draw_state      <= s2_process;
                    vga_req_fifo_rd_en  <= '0';
                
                when s2_process =>
                    -- 2 MSB give the type of operation
                    case vga_req_fifo_dout(38 downto 37) is
                        when "00" =>
                            vga_draw_state <= s_pixel_draw;
                        when "01" =>
                            vga_draw_state <= s_line_draw_init;
                        
                        -- when "10" =>
                        -- when "11" => 
                        
                        when others =>
                            vga_draw_state <= s0_idle;
                    
                    end case;
                
                when s_pixel_draw =>
                    -- Pixel drawing takes constant time -> we can go back to s0_idle state
                    vga_draw_state <= s0_idle;
                    
                when s_line_draw_init => 
                    vga_draw_state <= s_line_draw;
                    
                when s_line_draw =>
                    -- Line finished indicates that bresenham algorithm has finished.
                    -- Does not neccecarily mean that all the pixels have been put into RGB buffer.
                    -- Hence, another signal line_draw_pixels_copied is needed.
                    if (line_finished = '1') and (line_draw_pixels_copied = '1') then
                        vga_draw_state <= s0_idle;
                    else
                        vga_draw_state <= s_line_draw;
                    end if;
        
                when others => 
                    vga_draw_state <= s0_idle;
            
            end case;
        end if;
    end process;
    

end Behavioral;
