architecture AxiSendGet2 of TestCtrl is
  use      osvvm.ScoreboardPkg_slv.all;
  signal   TestDone : integer_barrier := 1 ;
  signal   SB : ScoreboardIDType;

   
begin

  ------------------------------------------------------------
  -- ControlProc
  --   Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  
  ControlProc : process
  begin
    SetTestName("Tb_send_data");
    TranscriptOpen;
    SetTranscriptMirror(TRUE);
    SetLogEnable(PASSED, FALSE);
    SetLogEnable(INFO, FALSE);
    

    -- Wait for testbench initialization 
    wait for 0 ns;
    wait until nReset = '1' ; 
	SB <= NEWID ("Score_Board"); 
    ClearAlerts;
    WaitForBarrier(TestDone, 10 ms);
    AlertIf(now >= 10 ms, "Test finished due to timeout");
    AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

    wait for 1 us;
    EndOfTestReports(ReportAll => TRUE);
    TranscriptClose;
    std.env.finish;
    wait;
  end process ControlProc;
  
  
  ------------------------------------------------------------
  -- AxiTransmitterProc
  --   Generate transactions for AxiTransmitter
  ------------------------------------------------------------
	AxiTransmitterProc : process
		variable rv : RandomPType;
		variable rand_data : std_logic_vector (DATA_WIDTH - 1 downto 0);
	begin
		wait until nReset = '1';
		WaitForClock(StreamTxRec, 2);
		
		rv.InitSeed("AxiTransmitterProc");  -- Use string literal or integer seed
	
		log("Send 1000 words with random values");
	
		for J in 0 to 999 loop  -- 1000 words
			rand_data := std_logic_vector (to_unsigned(J,32));  -- match DATA_WIDTH
			Push(SB, rand_data);
			Send(StreamTxRec, rand_data);
		end loop;
	
		WaitForClock(StreamTxRec, 2);
		WaitForBarrier(TestDone);
		wait;
	end process AxiTransmitterProc;
	


  ------------------------------------------------------------
  -- AxiReceiverProc
  --   Generate transactions for AxiReceiver
  ------------------------------------------------------------
  AxiReceiverProc : process
	variable ExpData : std_logic_vector(DATA_WIDTH-1 downto 0);
	variable RcvData : std_logic_vector(DATA_WIDTH-1 downto 0);
	begin
	WaitForClock(StreamRxRec, 2);
	
	log("Receive and check 1000 incrementing values");
	
	ExpData := (others => '0');
	for J in 0 to 999 loop
		Get(StreamRxRec, RcvData);
		if (RcvData(RcvData'high downto RcvData'high -2) = "00") then
			Check(SB,RcvData);
	        end if;
		log("Data Received: " & to_hstring(RcvData), Level => DEBUG);
	end loop;
	
	WaitForClock(StreamRxRec, 2);
	WaitForBarrier(TestDone);
	wait;
  end process AxiReceiverProc;


end AxiSendGet2 ;

Configuration Tb_send_data of TestHarness_fifo is
  for TestHarness
    for TestCtrl_5 : TestCtrl
      use entity work.TestCtrl(AxiSendGet2) ; 
    end for ; 
  end for ; 
end Tb_send_data ; 
