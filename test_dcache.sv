


`ifdef DEBUG
    $display("/*** DCACHE INFO ***/\n");
    $display("CACHE SIZE: %d\n", `DCACHE_SIZE);
    $display("CACHE BLOCK SIZE: %d\n", `DC_BLK_SZ);
    $display("N_IDX_BITS: %d\n", `N_IDX_BITS);
    `ifdef DIRECT_MAPPED
        $display("ASSOCIATIVITY: DIRECT MAPPED");
    `elsif TWO_WAY_SET_ASSOCIATIVE 
        $display("ASSOCIATIVITY: TWO WAY SET ASSOCIATIVE");
    `else
        $display("ASSOCIATIVITY: NOT DEFINED! ABORT!");
        $finish;
    `endif 
`endif 