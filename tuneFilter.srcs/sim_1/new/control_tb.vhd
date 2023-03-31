library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;
use work.tuneFilter_pkg.all;

entity control_tb is
end;

architecture bench of control_tb is

  component control
      Port (  clk, rst, RQ    : in STD_LOGIC;
              input           : in std_logic_vector(c_data_w-1 downto 0);
              GNT, RDY        : out STD_LOGIC;
              output          : out std_logic_vector(c_data_w-1 downto 0));
  end component;

  signal clk, rst, RQ: STD_LOGIC;
  signal input: std_logic_vector(c_data_w-1 downto 0);
  signal GNT, RDY: STD_LOGIC;
  signal output: std_logic_vector(c_data_w-1 downto 0);

  constant clock_period: time := 10 ns;
  signal stop_the_clock: boolean;

begin

  uut: control port map ( clk    => clk,
                          rst    => rst,
                          RQ     => RQ,
                          input  => input,
                          GNT    => GNT,
                          RDY    => RDY,
                          output => output );

  stimulus: process
  begin
  
    -- Put initialisation code here

    rst <= '1';
    wait for 5 ns;
    rst <= '0';
    wait for 5 ns;

    -- Put test bench stimulus code here
    report "test start";
    for i in 0 to 60 loop
      if  i < 1 then
        input <= x"2000";
      else 
        input <= x"0000";
      end if;
      RQ <= '1';
      wait on GNT;
      report ("calculation start "& integer'image(i));
      RQ <= '0';
      wait on GNT;
      wait on RDY;
      report ("calculation "& integer'image(i) &" end, result: "& real'image(real(to_integer(signed(output)))));
    end loop;
    
    assert (output = std_logic_vector(to_signed(3,c_data_w)))
      report ("wrong output, expected: " & integer'image(3) & "; Value read: " & integer'image(to_integer(signed(output))))
      severity error;
    if (output = std_logic_vector(to_signed(3,c_data_w))) then
      report "Test Successful!";
    else
      report "Test Failed!" severity error;
    end if;
    -------------
    wait for clock_period*5; 
    stop_the_clock <= true;
    wait;
  end process;

  clocking: process
  begin
    while not stop_the_clock loop
      clk <= '0', '1' after clock_period / 2;
      wait for clock_period;
    end loop;
    wait;
  end process;

end;
