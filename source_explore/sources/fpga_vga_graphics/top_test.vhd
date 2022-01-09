library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use IEEE.math_real.ALL; -- for floor

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity topMain is
    Port (  -- Inputs
            clk     : in STD_LOGIC;
            
            btn0    : in STD_LOGIC;
            btn1    : in STD_LOGIC;
            
            -- Outputs            
            pio1    : out STD_LOGIC;
            pio2    : out STD_LOGIC;
            pio16   : out STD_LOGIC;
            pio17   : out STD_LOGIC;
            pio48   : out STD_LOGIC;
            
            
            -- Extra outputs (not needed)
            led_0   : out STD_LOGIC;
            led_1   : out STD_LOGIC;
            led_2   : out STD_LOGIC;
            led_3   : out STD_LOGIC;
            
            led_r   : out STD_LOGIC;
            led_g   : out STD_LOGIC;
            led_b   : out STD_LOGIC
    );
end topMain;

architecture Behavioral of topMain is
    
    component VGA_Graphics_top is
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
    end component;
    
    -- Inputs
    signal flip_req              : STD_LOGIC; -- MUST BE PULSE
    signal destructive_read_req  : STD_LOGIC; -- flip and clear rgb_buff
            
    signal vga_req_fifo_din      : STD_LOGIC_VECTOR(38 DOWNTO 0);
    signal vga_req_fifo_wr_en    : STD_LOGIC;
    
    -- Outputs
    signal flip_in_progress_out  : STD_LOGIC;
    
    signal Colors                : STD_LOGIC_VECTOR(2 downto 0);
    signal HSync                 : STD_LOGIC;
    signal VSync                 : STD_LOGIC;
    
    
    -- Temp stuff
    signal btn0_prev : STD_LOGIC;
    signal btn1_prev : STD_LOGIC;
    
    --
    
    signal vga_req_type          : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal vga_req_x0            : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');
    signal vga_req_y0            : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal vga_req_x1            : STD_LOGIC_VECTOR(8 downto 0) := "000001100";
    signal vga_req_y1            : STD_LOGIC_VECTOR(7 downto 0) :=  "00001000";
    signal vga_req_color         : STD_LOGIC_VECTOR(2 downto 0) := "011";
    -- Combine all above into temporary signal below
    signal vga_req_fifo_din_temp : STD_LOGIC_VECTOR(38 DOWNTO 0) := (others => '0');
         
    --
       
    type myStateMachine_type is (s0, s1, s2);
    signal myStateMachine  : myStateMachine_type := s0;
    
    signal command : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal exec_command : STD_LOGIC := '0';
    
begin
    
    vga_req_fifo_din_temp <= vga_req_type & vga_req_x0 & vga_req_y0 & vga_req_x1 & vga_req_y1 & vga_req_color;
    
    --
        
    VGA_GPU : VGA_Graphics_top
    Port map ( 
        fpga_clk  => clk,
        cpu_clk   => clk, -- Note: This can be fpga_clk for now
        
        flip_req             => flip_req,
        destructive_read_req => destructive_read_req,
        
        vga_req_fifo_din     => vga_req_fifo_din_temp,
        vga_req_fifo_wr_en   => vga_req_fifo_wr_en,
        
        -- Outputs
        flip_in_progress_out => flip_in_progress_out, -- is flipping in progress i.e., are we copying rgb-buff to vga_buff
        
        -- Outputs (to actual fpga pin-outs)
        Colors  => Colors,
        HSync   => HSync,
        VSync   => VSync
    );
    
    statemachine : process(clk, command, exec_command) is
    begin
        if rising_edge(clk) then
            if exec_command = '1' then
                case command is
                    -- Non destrcutive flip
                    when "0000" =>
                        flip_req <= '1';
                        destructive_read_req <= '0';
                    -- Destrucitve flip
                    when "0001" => 
                        flip_req <= '1';
                        destructive_read_req <= '1';
                    
                    -----------
                    -- Draw pixel and x0++
                    when "0010" => 
                        vga_req_x0 <= std_logic_vector(unsigned(vga_req_x0) + 1);
                        vga_req_type <= "00";
                        vga_req_fifo_wr_en <= '1';
                        
                    -- Draw line and y1++
                    when "0011" => 
                        vga_req_y1 <= std_logic_vector(unsigned(vga_req_y1) + 1);
                        vga_req_type <= "01";
                        vga_req_fifo_wr_en <= '1';
                        
                    ---- color++
                    when "0100" =>
                        vga_req_color <= std_logic_vector(unsigned(vga_req_color) + 1);
                        
                    ---- x0++ or y0++
                    when "0101" =>
                        vga_req_x0 <= std_logic_vector(unsigned(vga_req_x0) + 1);
                    when "0110" =>
                        vga_req_y0 <= std_logic_vector(unsigned(vga_req_y0) + 1);
                    ---- x1++ or y1++
                    when "0111" =>
                        vga_req_x1 <= std_logic_vector(unsigned(vga_req_x1) + 1);
                    when "1000" =>
                        vga_req_y1 <= std_logic_vector(unsigned(vga_req_y1) + 1);
                    
                               
                    when others => 
                        --
                        
                end case;
                
            else
            
                vga_req_fifo_wr_en <= '0';
                flip_req <= '0';
                
            end if;
        end if;
    end process;
    
    someTestProcess : process(clk) is
    begin
        if rising_edge(clk) then
            btn0_prev <= btn0;
            btn1_prev <= btn1;
            
            if btn0_prev = '0' and btn0 = '1' then
                command <= std_logic_vector(to_unsigned(to_integer(unsigned(command)) + 1, command'length));
            end if;
               
            if exec_command = '1' then
                command <= (others => '0');
                exec_command <= '0';
            elsif btn1_prev = '0' and btn1 = '1' then  
                exec_command <= '1';    
            end if;
              
        end if;
    end process;
    
    pio1  <= HSync;
    pio2  <= VSync;
    pio16 <= Colors(0);
    pio17 <= Colors(1);
    pio48 <= Colors(2);
    
    -- Not actually needed
    led_0 <= command(0);
    led_1 <= command(1);
    led_2 <= command(2);
    led_3 <= command(3);
    
    
    -- Turning off Cmod-S7 RGB led
    led_r <= '1'; led_g <= '1'; led_b <= '1';
    
end Behavioral;
