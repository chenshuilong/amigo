class CreateDefinitions < ActiveRecord::Migration
  def up
    create_table :definitions do |t|
      t.integer  :project_id

      # 命名及市场定位
      t.text     :internal_version_desc         # 内部型号-描述
      t.text     :mobile_public_cta             # 移动公开版CTA入网型号
      t.text     :mobile_public_cta_desc        # 移动公开版CTA入网型号-描述
      t.text     :propaganda_version            # 宣传型号
      t.text     :propaganda_version_desc       # 宣传型号-描述
      t.text     :product_position              # 产品定位
      t.text     :product_position_desc         # 产品定位-描述
      t.text     :product_series                # 产品系列
      t.text     :product_series_desc           # 产品系列-描述
      t.text     :selling_point                 # 最强卖点
      t.text     :selling_point_desc            # 最强卖点-描述
      t.text     :target_population             # 目标人群
      t.text     :target_population_desc        # 目标人群-描述
      t.datetime :product_dt                    # 目标量产时间
      t.text     :product_dt_desc               # 目标量产时间-描述
      t.text     :production_version            # 版本号（产品定义）
      t.text     :production_version_desc       # 版本号（产品定义）-描述
      #
      # # 产品定义 -- ID
      # # 尺寸
      # t.string :id_size_spec                    # 尺寸-规格
      # t.text   :id_size_desc                    # 尺寸-描述
      # t.string :id_size_perf                    # 尺寸-性能要求
      # t.string :id_size_bench                   # 尺寸-对标机型
      # # 颜色
      # t.string :color_spec                      # 颜色-规格
      # t.text   :color_desc                      # 颜色-描述
      # t.string :color_perf                      # 颜色-性能要求
      # t.string :color_bench                     # 颜色-对标机型
      # # 重量
      # t.string :weight_spec                     # 重量-规格
      # t.text   :weight_desc                     # 重量-描述
      # t.string :weight_perf                     # 重量-性能要求
      # t.string :weight_bench                    # 重量-对标机型
      # # 产品外观
      # t.string :appearance_spec                 # 产品外观-规格
      # t.text   :appearance_desc                 # 产品外观-描述
      # t.string :appearance_perf                 # 产品外观-性能要求
      # t.string :appearance_bench                # 产品外观-对标机型
      # # 按键布局
      # t.string :key_layout_spec                 # 按键布局-规格
      # t.text   :key_layout_desc                 # 按键布局-描述
      # t.string :key_layout_perf                 # 按键布局-性能要求
      # t.string :key_layout_bench                # 按键布局-对标机型


      t.timestamps null: false
    end

    Project.active.where("category <> 4").each do |p|
      definition = Definition.new
      definition.project_id = p.id
      definition.save
    end
  end

  def down
    drop_table :definitions

    Definition.destroy_all
  end
end
