`include "internal_defines.vh"
`include "column.sv"
`define DEBUG 0

module column_test;
    logic rst_n, addr_clear, clk;

    logic [`MEM_WORD_BITS-1:0] mem_word;
    logic                      data_valid;
    logic [`MEM_ADDR_BITS-1:0] addr;
    logic [$clog2(`NEURONS_PER_COLUMN)-1:0] winner;
    logic training, testing, valid, no_winner;

    logic [7:0] train_images [$];
    logic [7:0] test_images [$];
    logic [7:0] labels [$];

    logic [`NEURONS_PER_COLUMN-1:0][0:9][31:0] confusion_matrix;

    column dut(.*);

    task display_rf_data();
      $display("Input data valid %b", data_valid);
      $display("rf_valid: %b, filter_ready: %b", 
        dut.rf_valid, 
        dut.RF.filter_ready);
      $display("Receptive Field output is:");
      for (int i = 0; i < dut.RF.ROWS; i++) begin
        $write("\t");
        for (int j = 0; j < dut.RF.COLS; j++) begin
          $write(" %x",dut.rf_buffer[i][j]);
        end
        $write("\n");
      end
    endtask : display_rf_data

    task display_filter_data(input int disp_on, input int disp_off);
      if (disp_on) begin
        $display("en_acc_reg (ON): %b", dut.ON_FILTER.filter_inst.en_acc_reg);
        $display("On Filter captured padded input as:");
        for (int i = 0; i < dut.ON_FILTER.PADDED_HEIGHT; i++) begin
          $write("\t");
          for (int j = 0; j < dut.ON_FILTER.PADDED_WIDTH; j++) begin
            $write(" %x",dut.ON_FILTER.filter_inst.padded_in[i][j]);
          end
          $write("\t");
          for (int j = 0; j < dut.ON_FILTER.PADDED_WIDTH; j++) begin
            $write(" %d",dut.ON_FILTER.filter_inst.padded_in[i][j]);
          end
          $write("\n");
        end
        $display("On Filter, sum of neighbors:");
        for (int i = 0; i < dut.ON_FILTER.filter_inst.ROWS; i++) begin
          $write("\t");
          for (int j = 0; j < dut.ON_FILTER.filter_inst.COLS; j++) begin
            $write(" %x",dut.ON_FILTER.filter_inst.sums[i][j]);
          end
          $write("\t");
          for (int j = 0; j < dut.ON_FILTER.filter_inst.COLS; j++) begin
            $write(" %d",dut.ON_FILTER.filter_inst.sums[i][j]);
          end
          $write("\n");
        end
        $display("On Filter, average of neighbors:");
        for (int i = 0; i < dut.ON_FILTER.filter_inst.ROWS; i++) begin
          $write("\t");
          for (int j = 0; j < dut.ON_FILTER.filter_inst.COLS; j++) begin
            $write(" %x",dut.ON_FILTER.filter_inst.quotients[i][j]);
          end
          $write("\t");
          for (int j = 0; j < dut.ON_FILTER.filter_inst.COLS; j++) begin
            $write(" %d",dut.ON_FILTER.filter_inst.quotients[i][j]);
          end
          $write("\n");
        end
        $display("On Filter, val - average of neighbors valid on %b",
          dut.ON_FILTER.filter_inst.filter_done);
        for (int i = 0; i < dut.ON_FILTER.filter_inst.ROWS; i++) begin
          $write("\t");
          for (int j = 0; j < dut.ON_FILTER.filter_inst.COLS; j++) begin
            $write(" %x",dut.ON_FILTER.filter_inst.filtered_out[i][j]);
          end
          $write("\t");
          for (int j = 0; j < dut.ON_FILTER.filter_inst.COLS; j++) begin
            $write(" %d",dut.ON_FILTER.filter_inst.filtered_out[i][j]);
          end
          $write("\n");
        end
        $display("On Filter, thermometer coded values, in_valid for fire is %b",
          dut.ON_FILTER.spike_gen.in_valid);
        for (int i = 0; i < dut.ON_FILTER.spike_gen.HEIGHT; i++) begin
          $write("\t");
          for (int j = 0; j < dut.ON_FILTER.spike_gen.WIDTH; j++) begin
            $write(" %b",dut.ON_FILTER.spike_gen.thermometer_coded_img[i][j]);
          end
          $write("\t");
          for (int j = 0; j < dut.ON_FILTER.spike_gen.WIDTH; j++) begin
            $write(" %d",dut.ON_FILTER.spike_gen.thermometer_coded_img[i][j]);
          end
          $write("\n");
        end
        $display("timestep = %d, en_counter = %b",
          dut.ON_FILTER.cycle, dut.ON_FILTER.en_counter);
        $display("On Filter, generated spikes are, fire in_valid=%b, ready=%b:",
          dut.ON_FILTER.spike_gen.in_valid, dut.ON_FILTER.spike_gen.ready);
        for (int i = 0; i < dut.ON_FILTER.spike_gen.HEIGHT; i++) begin
          $write("\t");
          for (int j = 0; j < dut.ON_FILTER.spike_gen.WIDTH; j++) begin
            $write(" %b",
              dut.ON_FILTER.spike_gen.spikes[i * dut.ON_FILTER.spike_gen.WIDTH + j]);
          end
          $write("\n");
        end

      end
      if (disp_off) begin
        $display("en_acc_reg (OFF): %b", dut.OFF_FILTER.filter_inst.en_acc_reg);
        $display("Off Filter captured padded input as:");
        for (int i = 0; i < dut.OFF_FILTER.PADDED_HEIGHT; i++) begin
          $write("\t");
          for (int j = 0; j < dut.OFF_FILTER.PADDED_WIDTH; j++) begin
            $write(" %x",dut.OFF_FILTER.filter_inst.padded_in[i][j]);
          end
          $write("\t");
          for (int j = 0; j < dut.OFF_FILTER.PADDED_WIDTH; j++) begin
            $write(" %d",dut.OFF_FILTER.filter_inst.padded_in[i][j]);
          end
          $write("\n");
        end
        $display("Off Filter, sum of neighbors:");
        for (int i = 0; i < dut.OFF_FILTER.filter_inst.ROWS; i++) begin
          $write("\t");
          for (int j = 0; j < dut.OFF_FILTER.filter_inst.COLS; j++) begin
            $write(" %x",dut.OFF_FILTER.filter_inst.sums[i][j]);
          end
          $write("\t");
          for (int j = 0; j < dut.OFF_FILTER.filter_inst.COLS; j++) begin
            $write(" %d",dut.OFF_FILTER.filter_inst.sums[i][j]);
          end
          $write("\n");
        end
      end
    endtask : display_filter_data

    task display_neuron_data(input int neuron_id);
      for (int i = 0; i < `RF_HEIGHT; i++) begin
        $write("\t");
        for (int j = 0; j < `RF_WIDTH; j++) begin
          $write(" %b", dut.EC.in_spikes[neuron_id][i * `RF_WIDTH + j]);
        end
        $write("\t");
        for (int j = 0; j < `RF_WIDTH; j++) begin
          $write(" %b", dut.EC.in_weights[neuron_id][i * `RF_WIDTH + j]);
        end
        if (i == `RF_HEIGHT - 1) begin
          $write("\t%b", dut.EC.out_spikes[neuron_id]);
        end
        $write("\n");
      end
    endtask : display_neuron_data

    task display_ec_data(input int neuron_id);
      $display("Displaying the Excitatory Column data");
      $display("Looking at %d neurons with %d synapses each",
        dut.EC.NEURONS, dut.EC.SYNAPSES);
      if (neuron_id < 0) begin
        for (int i = 0; i < dut.EC.NEURONS; i++) begin
          display_neuron_data(neuron_id);
        end
      end else begin
        display_neuron_data(neuron_id);
      end
    endtask : display_ec_data

    task display_stdp_data();
      $display("Displaying STDP weights");
      for (int i = 0; i < dut.stdplasticity.NEURONS; i++) begin
        $display("Looking at neuron %3d:", i);
        for (int j = 0; j < `RF_HEIGHT; j++) begin
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.weights[i][j * `RF_WIDTH + k]);
          end
          $write("\n");
        end
      end
      $display("Displaying STDP old_weights");
      for (int i = 0; i < dut.stdplasticity.NEURONS; i++) begin
        $display("Looking at neuron %3d:", i);
        for (int j = 0; j < `RF_HEIGHT; j++) begin
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.old_weights[i][j * `RF_WIDTH + k]);
          end
          $write("\n");
        end
      end
      $display("Displaying STDP b_min, f_plus, f_minus, max_f_pos_b_min, max_f_neg_b_min");
      for (int i = 0; i < dut.stdplasticity.NEURONS; i++) begin
        $display("Looking at neuron %3d:", i);
        for (int j = 0; j < `RF_HEIGHT; j++) begin
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.b_min[i][j * `RF_WIDTH + k]);
          end
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.f_plus[i][j * `RF_WIDTH + k]);
          end
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.f_minus[i][j * `RF_WIDTH + k]);
          end
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.max_f_pos_b_min[i][j * `RF_WIDTH + k]);
          end
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.max_f_neg_b_min[i][j * `RF_WIDTH + k]);
          end
          $write("\n");
        end
      end
      $display("Displaying STDP b_branch thresholds, thresh_sel");
      for (int i = 0; i < dut.stdplasticity.NEURONS; i++) begin
        $display("Looking at neuron %3d:", i);
        for (int j = 0; j < `RF_HEIGHT; j++) begin
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %d", dut.stdplasticity.random_vars.branch_threshold[i][j * `RF_WIDTH + k]);
          end
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %d", dut.stdplasticity.random_vars.thresh_sel[i][j * `RF_WIDTH + k]);
          end
          $write("\n");
        end
      end
      $display("Displaying STDP b_branch, branch1, branch2, branch3, branch4");
      for (int i = 0; i < dut.stdplasticity.NEURONS; i++) begin
        $display("Looking at neuron %3d:", i);
        for (int j = 0; j < `RF_HEIGHT; j++) begin
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.b_branch[i][j * `RF_WIDTH + k]);
          end
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.branch1[i][j * `RF_WIDTH + k]);
          end
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.branch2[i][j * `RF_WIDTH + k]);
          end
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.branch3[i][j * `RF_WIDTH + k]);
          end
          $write("\t");
          for (int k = 0; k < `RF_WIDTH; k++) begin
            $write(" %b", dut.stdplasticity.branch4[i][j * `RF_WIDTH + k]);
          end
          $write("\n");
        end
      end
    endtask : display_stdp_data

    always_ff @(posedge clk) begin
      if (`DEBUG) begin
        $display("***********************************************************");
        $display("Cycle:%5d", $time);
        display_rf_data();
        display_filter_data(1,0);
        display_ec_data(0);
        display_stdp_data();
        $display("***********************************************************");
      end
    end

    initial begin
      clk = 1;
      forever #5 clk = ~clk;
    end

    initial begin
      real spikes,maxval, maxes;
      int maxi, imagenum;
      int train_size, test_size;
      string train_file, test_file, test_labels;
      if (!$value$plusargs("TRAIN=%s", train_file))
          train_file = "../../data/train.images.mem";
      if (!$value$plusargs("TEST=%s", test_file))
          test_file = "../../data/test.images.mem";
      if (!$value$plusargs("LABELS=%s", test_labels))
          test_labels = "../../data/test.labels.mem";
      // real spikes, n, maxval, maxes;
      // int maxi;
      // confusion_matrix = '0;
      // $display("Reading training images into memory");
      // $readmemh("../../data/small.images.mem", train_images);
    
      // mem_word = '0;
      // data_valid = 1'b0;
      // training = 0;
      // testing = 0;
      // rst_n = 0;
      // rst_n <= 1;
      // @(posedge clk);
      // @(posedge clk);
      // data_valid = 1'b1;
      // @(posedge clk);
      // mem_word = train_images[addr];
      // data_valid = 1'b0;

      // @(posedge clk);
      // mem_word = '0;
      // data_valid = 1'b1;
      // @(posedge clk);
      // mem_word = train_images[addr];
      // data_valid = 1'b0;

      // @(posedge clk);
      // mem_word = '0;
      // data_valid = 1'b0;
      // @(posedge clk);
      // @(posedge clk);
      // @(posedge clk);
      // @(posedge clk);
      // data_valid = 1'b1;
      // @(posedge clk);
      // mem_word = train_images[addr];
      // data_valid = 1'b0;
        

      // $display("Beginning clustering training images: n=%5d", train_size);
      // repeat (2*(`NUM_TRAIN_IMAGES * `RF_HEIGHT * `RF_WIDTH) - 1) begin 
      //   @(posedge clk);
      //   mem_word = '0;
      //   data_valid = 1'b1;
      //   @(posedge clk);
      //   mem_word = train_images[addr];
      //   data_valid = 1'b0;
      // end
      // @(posedge clk);
      // data_valid = 1'b0;

      confusion_matrix = '0;
      $display("Reading training images into memory");
      $display("Files %s, %s, %s", train_file, test_file, test_labels);
      $readmemh(train_file, train_images);
      $readmemh(test_file, test_images);
      $readmemh(test_labels, labels);
      
      if (!$value$plusargs("TRAINSIZE=%d", train_size))
        train_size = train_images.size() / (`IMG_HEIGHT * `IMG_WIDTH);

      if (!$value$plusargs("TESTSIZE=%d", test_size))
        test_size = test_images.size() / (`IMG_HEIGHT * `IMG_WIDTH);

      mem_word = '0;
      addr_clear = 1'b0;
      data_valid = 1'b0;
      training = 0;
      testing = 0;
      rst_n = 0;
      rst_n <= 1;
      data_valid <= 1'b1;        
      @(posedge clk);

      $display("Beginning clustering training images: n=%5d", train_size);
      for (int i = 0; i < train_size; i++) begin
        if (i % 100 == 0) begin
          $display("Clustering %d train images", i);
          $system("date");
        end
        for (int j = 0; j < (`RF_HEIGHT * `RF_WIDTH); j++) begin
          mem_word <= train_images[addr];
          data_valid <= 1'b1;
          @(posedge clk);
        end
      end
      mem_word <= train_images[addr];
      data_valid <= 1'b0;
      repeat (20) begin
        mem_word <= '0;
        @(posedge clk);
      end

      @(posedge clk);
      @(posedge clk);
      @(posedge clk);
      addr_clear = 1'b1;
      @(posedge clk);
      addr_clear = 1'b0;
      @(posedge clk);

      data_valid <= 1'b1;
      @(posedge clk);
      spikes = 0;
      imagenum = 0;
      $display("Beginning clustering test images: n=", test_size);
      for (int i = 0; i < test_size; i++) begin
        if (i % 100 == 0) begin
          $display("Clustering %d test images", i);
          $system("date");
        end
        for (int j = 0; j < `RF_HEIGHT * `RF_WIDTH; j++) begin
          mem_word <= test_images[addr];
          @(posedge clk);
          if (valid) begin
            if (!no_winner) begin
              spikes++;
              confusion_matrix[winner][labels[imagenum]] += 1;
            end
            imagenum++;
          end
        end
      end
      mem_word <= train_images[addr];
      data_valid <= 1'b0;
      repeat (20) begin
        mem_word <= '0;
        @(posedge clk);
      end

      $display("Results:");
      $display("Confusion matrix:");
      for (int i = 0; i < `NEURONS_PER_COLUMN; i++) begin
        $write("neuron %2d", i);
        maxi = 0;
        maxval = 0;
        for (int j = 0; j < 10; j++) begin
          if (confusion_matrix[i][j] > maxval) begin
            maxi = i;
            maxval = confusion_matrix[i][j];
          end
          $write("%4d ", confusion_matrix[i][j]);
        end
        $write("\n");
        maxes += maxval;
      end

      $display("\nPurity: %f", maxes / spikes);
      $display("Coverage: %f", spikes / test_size);
      #10 $finish;
    end
endmodule : column_test
