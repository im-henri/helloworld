library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Bresenham_linedraw is
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
end Bresenham_linedraw;

            
architecture Behavioral of Bresenham_linedraw is
    
    
    component fifo_linedraw is
    Port (
            clk     : IN STD_LOGIC;
            din     : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
            wr_en   : IN STD_LOGIC;
            rd_en   : IN STD_LOGIC;
            dout    : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
            full    : OUT STD_LOGIC;
            empty   : OUT STD_LOGIC
    );
    end component;

    component LUT_mult320 IS
    Port (
            clka    : IN  STD_LOGIC;
            addra   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            douta   : OUT STD_LOGIC_VECTOR(16 DOWNTO 0)
    );
    end component;

    type drawing_state_type is (s0_wait, s1_initialize1, s1_initialize2, s2_perform1, s2_perform2, s3_finish);
    signal drawing_state : drawing_state_type   := s0_wait;
    
    signal drawing_done  : STD_LOGIC;


    -- sx and sy , in decimal either +1 or -1
    signal sx  : STD_LOGIC_VECTOR(1 downto 0);
    signal sy  : STD_LOGIC_VECTOR(1 downto 0);
    
    signal dx  : STD_LOGIC_VECTOR(8+1 downto 0);
    signal dy  : STD_LOGIC_VECTOR(7+1 downto 0);
    
    -- Extra bit for err, errx, erry - for sign bit 
    signal err  : STD_LOGIC_VECTOR(8+1 downto 0); -- ceil(log2(sqrt(320**2 + 240**2))) wide
    signal errx : STD_LOGIC_VECTOR(8+1 downto 0); -- ceil(log2(320)) wide
    signal erry : STD_LOGIC_VECTOR(7+1 downto 0); -- ceil(log2(240)) wide
    
    
    -- Latched values (means that data into this block does not need to persist after draw request)
    signal x0           : STD_LOGIC_VECTOR(8 downto 0);
    signal y0           : STD_LOGIC_VECTOR(7 downto 0);
    signal x1           : STD_LOGIC_VECTOR(8 downto 0);
    signal y1           : STD_LOGIC_VECTOR(7 downto 0);
    signal pixel_color  : STD_LOGIC_VECTOR(2 downto 0);
    signal pixel_addr   : STD_LOGIC_VECTOR(16 downto 0);
    signal push_pixel   : STD_LOGIC;
    
    signal pixel_data_temp : STD_LOGIC_VECTOR(19 downto 0); -- used only to connect component
    
    signal y0_mult320   : STD_LOGIC_VECTOR(16 downto 0);
begin
    
    pixel_data_temp <= pixel_addr & pixel_color; 
    
    fifo_pixel_data : fifo_linedraw 
    Port map (
            clk     =>  clk,
            din     =>  pixel_data_temp,
            wr_en   =>  push_pixel,
            rd_en   =>  pop_pixel,
            dout    =>  pixel_dout,
            full    =>  open,
            empty   =>  fifo_empty
    );
    
    
    mult_320 : LUT_mult320
    Port map (
            clka    => clk,
            addra   => y0,
            douta   => y0_mult320
    );
    
    state_using : process(clk, drawing_state, draw_req, x0_in, y0_in, x1_in, y1_in) is
      
    begin
        if rising_edge(clk) then
            case drawing_state is
                when s0_wait =>
                    push_pixel   <= '0';
                    
                    -- Latch line start and end positions, and color of line 
                    if draw_req = '1' then
                        x0 <= x0_in;
                        y0 <= y0_in;
                        x1 <= x1_in;
                        y1 <= y1_in;
                        pixel_color  <= color_in;
                        
                        line_finished <= '0';
                    end if;
                    
                when s1_initialize1 =>
                    -- Reset done signal
                    drawing_done <= '0';
                    
                    push_pixel   <= '0';
                    
                    dx <= STD_LOGIC_VECTOR(to_unsigned(abs( to_integer(unsigned(x1)) - to_integer(unsigned(x0)) ), dx'length));
                    dy <= STD_LOGIC_VECTOR(to_unsigned(abs( to_integer(unsigned(y1)) - to_integer(unsigned(y0)) ), dy'length));
                    
                    if signed(x0) < signed(x1) then
                        sx <= STD_LOGIC_VECTOR(to_signed(1, sx'length));
                    else
                        sx <= STD_LOGIC_VECTOR(to_signed(-1, sx'length));
                    end if;
                    
                    if signed(y0) < signed(y1) then
                        sy <= STD_LOGIC_VECTOR(to_signed(1, sy'length));
                    else
                        sy <= STD_LOGIC_VECTOR(to_signed(-1, sy'length));
                    end if;                  
                    
                when s1_initialize2 =>
                    -- err initial value split-into two phases to avoid clk-to-q latency issues
                    err <= STD_LOGIC_VECTOR(to_signed(to_integer(unsigned(dx)) - to_integer(unsigned(dy)), err'length));
                  
                when s2_perform1 => 
                    -- Push pixel to fifo
                    push_pixel   <= '1';
                    
                     -- pixel_addr's y0_mult320 should have no clk-to-q clock latency issue 
                    -- as y0 is connected to y0_mult320 (memory block) and y0 is set during previous phase
                    -- i.e., s2_perform1 phase
                    pixel_addr  <= std_logic_vector(unsigned(y0_mult320) + unsigned(x0));                            
  
                    -- Advance x
                    if (2 * to_integer(signed(err))) > (- to_integer(unsigned(dy))) then
                        erry <= std_logic_vector(to_signed((- to_integer(unsigned(dy))), erry'length));
                        -- x0 will be natural i.e., above 0.
                        x0   <= std_logic_vector(to_unsigned(to_integer(unsigned(x0)) + to_integer(signed(sx)), x0'length));
                    else
                        erry <= (others => '0');
                        x0   <= x0; -- Just to clarify for reader     
                    end if;         
                    
                    -- Advance y
                    if (2 * to_integer(signed(err))) < (to_integer(unsigned(dx))) then
                        errx <= std_logic_vector( to_signed(to_integer(unsigned(dx)), errx'length) );
                        -- y0 will be natural i.e., above 0.
                        y0   <= std_logic_vector(to_unsigned(to_integer(unsigned(y0)) + to_integer(signed(sy)), y0'length));
                    else
                        errx <= (others => '0');
                        y0   <= y0; -- Just to clarify for reader     
                    end if; 
                    
                when s2_perform2 =>   
                    push_pixel <= '0';
                    
                    -- err = err + errx + erry
                    err <= std_logic_vector(to_signed(to_integer(signed(err)) + to_integer(signed(errx)) + to_integer(signed(erry)), err'length));
                    
                    -- Stopping criteria (if first end reaches other end)
                    if x0 = x1 and y0 = y1 then
                        drawing_done <= '1';
                    end if;
                    
                when s3_finish =>   
                    -- Set done signale
                    push_pixel    <= '0';
                    line_finished <= '1';
                    
                when others => 
                    -- Should never be reached  
            end case;
        end if;
    end process;
    
    
    -- Only state switching is here
    state_switching : process(clk, drawing_state, draw_req, drawing_done) is
    begin
        if rising_edge(clk) then
            case drawing_state is
                when s0_wait =>
                    -- Start initialization phase when drawing is requested
                    if draw_req = '1' then
                        drawing_state <= s1_initialize1;
                    else
                        drawing_state <= s0_wait;
                    end if;
                
                when s1_initialize1 =>
                    drawing_state <= s1_initialize2;
                
                when s1_initialize2 =>
                    drawing_state <= s2_perform1;
                    
                when s2_perform1 =>   
                    drawing_state <= s2_perform2;  
                    
                when s2_perform2 =>   
                    if drawing_done = '1' then
                        drawing_state <= s3_finish;
                    else 
                        drawing_state <= s2_perform1;
                    end if;
                    
                when s3_finish =>   
                    -- Do some finishing stuff if needed
                    drawing_state <= s0_wait;
                
                when others => 
                    drawing_state <= s0_wait;
            end case;
        end if;
    end process;

end Behavioral;
