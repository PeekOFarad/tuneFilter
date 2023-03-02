----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 02/10/2023 10:02:35 AM
-- Design Name:
-- Module Name: top - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
-- library UNISIM;
-- use UNISIM.VComponents.all;

entity top is
  port (
    data_in  : in    std_logic_vector(15 downto 0);
    data_out : out   std_logic_vector(15 downto 0);
    clk      : in    std_logic;
    rst      : in    std_logic;
    rq       : in    std_logic;
    gnt      : out   std_logic;
    rdy      : out   std_logic
  );
end entity top;

architecture behavioral of top is

begin

end architecture behavioral;
