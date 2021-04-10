# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance/tensor_eval/tensor_eval'

class TensorEvalMatrixPerfTest < TensorEvalPerfTest

  def setup
    super
    set_owner("geirst")
  end

  def test_tensor_evaluation_matrix
    set_description("Test performance of tensor matrix product")
    @graphs = get_graphs_matrix
    deploy_and_feed(5000)

    [10,25,50,100].each do |dim_size|
      rank_profile = "tensor_matrix_product_#{dim_size}x#{dim_size}"
      query_file = "queries.tensor.dense.#{dim_size}.txt"
      run_fbench_helper(MATRIX_PRODUCT, rank_profile, dim_size, query_file)
    end
  end

  def get_graphs_matrix
    [
      get_latency_graphs_for_eval_type(MATRIX_PRODUCT),
      get_latency_graph_for_rank_profile("tensor_matrix_product_25x25", 25, 1.65, 2.00)
    ]
  end

  def teardown
    super
  end

end
