library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity imageGeneratorVGA is
    Generic (
            -- NOTE THAT THIS IS DIVIDED BY 2. Both H and V
            constant H_VISIBLE_AREA  : natural := 640;
            constant V_VISIBLE_AREA  : natural := 480;
            
            constant pixel_ADDR_WIDTH : natural := 17
    );
    Port (  -- Inputs
            clk : in STD_LOGIC;
            
            HSync : in STD_LOGIC;
            VSync : in STD_LOGIC;
            
            HCounter : in natural;
            VCounter : in natural;
            
            -- From dual-port-RAM
            rBufferData : in STD_LOGIC;
            gBufferData : in STD_LOGIC;
            bBufferData : in STD_LOGIC;
            -- To dual-port-RAM
            pixelAddr   : out STD_LOGIC_VECTOR(pixel_ADDR_WIDTH-1 downto 0);
            
            -- Outputs
            color_out : out STD_LOGIC_VECTOR(2 downto 0)
    );
end imageGeneratorVGA;


architecture Behavioral of imageGeneratorVGA is
    
    signal dout_delayed1 : STD_LOGIC_VECTOR(2 downto 0);
    signal dout_delayed2 : STD_LOGIC_VECTOR(2 downto 0);
    signal dout_delayed3 : STD_LOGIC_VECTOR(2 downto 0);
    signal dout_delayed4 : STD_LOGIC_VECTOR(2 downto 0);
    
begin
    
    process(clk, HCounter, VCounter, HSync, VSync) is
        variable memoryPlace          : STD_LOGIC_VECTOR(pixel_ADDR_WIDTH downto 0);
        variable vcounter_vector_temp : STD_LOGIC_VECTOR(8 downto 0);

        --variable which_row   : STD_LOGIC := '1';
        --variable hcounter_vector_temp : STD_LOGIC_VECTOR(9 downto 0);

    begin
        if rising_edge(clk) then
            if (HCounter <= (H_VISIBLE_AREA-1)) and (VCounter <= (V_VISIBLE_AREA-1)) then
                -- Getting color out of block ram 
                
                if HCounter = 0 and VCounter = 0 then
                    memoryPlace := (others => '0');
                else
                    memoryPlace := STD_LOGIC_VECTOR( unsigned(memoryPlace) + 1 );
                end if;
                
                -- Skip the LSB of the pixel address to essentially increment every other cycle
                pixelAddr      <= memoryPlace(pixel_ADDR_WIDTH downto 1);
                --pixelAddr      <= (others => '0');
                

                dout_delayed1  <= rBufferData & gBufferData & bBufferData;
                dout_delayed2  <= dout_delayed1;
            
                color_out <= dout_delayed2;

            else
                -- Once every end of the row, check if we need to repeat the content of the row
                if HCounter = H_VISIBLE_AREA then
                    -- Check if VCounter is even i.e., LSB is '0' that means that next row is the same as previous row
                    -- i.e., memoryplace must be reduced by screen_x_size in VGA buff, which is 640/2 = 320
                    vcounter_vector_temp := STD_LOGIC_VECTOR(to_unsigned(VCounter, vcounter_vector_temp'length));
                    if vcounter_vector_temp(0) = '0' then
                        memoryPlace := STD_LOGIC_VECTOR( unsigned(memoryPlace) - 640 );
                    end if;

                end if;
                
                color_out <= (others => '0'); 
            end if;
                  
        end if;
    end process;  
    
end Behavioral;
