require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'During migrations' do
    let(:db) {DBSpecHelper.db}
    let(:migration_file) {'20171113000000_add_links_api.rb'}

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'creates the appropriate tables' do
      DBSpecHelper.migrate(migration_file)
      expect(db.table_exists? :link_providers).to be_truthy
      expect(db.table_exists? :link_providers_intents).to be_truthy
      expect(db.table_exists? :link_consumers).to be_truthy
      expect(db.table_exists? :link_consumers_intents).to be_truthy
      expect(db.table_exists? :links).to be_truthy
      expect(db.table_exists? :instances_links).to be_truthy
    end

    context 'providers migration' do
      context 'when link_spec_json is populated in the deployments table' do
        let(:link_spec_json) do
          {
            'provider_instance_group_1': {
              'provider_job_1': {
                'link_name_1': {
                  'link_type_1': {'my_val': 'hello'}
                },
                'link_name_2': {
                  'link_type_2': {'foo': 'bar'}
                }
              }
            },
            'provider_instance_group_2': {
              'provider_job_1': {
                'link_name_3': {
                  'link_type_1': {'bar': 'baz'}
                },
              },
              'provider_job_2': {
                'link_name_4': {
                  'link_type_2': {'foobar': 'bazbaz'}
                }
              }
            }
          }
        end

        before do
          db[:deployments] << {name: 'fake-deployment', id: 42, link_spec_json: link_spec_json.to_json}
          DBSpecHelper.migrate(migration_file)
        end

        it 'will create correct links providers' do
          expect(db[:link_providers].count).to eq(3)

          expected_links_providers = [
            {instance_group: 'provider_instance_group_1', deployment_id: 42, type: 'job', name: 'provider_job_1'},
            {instance_group: 'provider_instance_group_2', deployment_id: 42, type: 'job', name: 'provider_job_1'},
            {instance_group: 'provider_instance_group_2', deployment_id: 42, type: 'job', name: 'provider_job_2'},
          ]

          db[:link_providers].order(:id).each_with_index do |provider, index|
            output = expected_links_providers[index]
            expect(provider[:name]).to eq(output[:name])
            expect(provider[:deployment_id]).to eq(output[:deployment_id])
            expect(provider[:instance_group]).to eq(output[:instance_group])
            expect(provider[:type]).to eq(output[:type])
          end
        end

        it 'will create correct links providers intents' do
          provider_1_id = db[:link_providers].where(instance_group: 'provider_instance_group_1', deployment_id: 42, type: 'job', name: 'provider_job_1').first[:id]
          provider_2_id = db[:link_providers].where(instance_group: 'provider_instance_group_2', deployment_id: 42, type: 'job', name: 'provider_job_1').first[:id]
          provider_3_id = db[:link_providers].where(instance_group: 'provider_instance_group_2', deployment_id: 42, type: 'job', name: 'provider_job_2').first[:id]

          expected_link_providers_intents = [
            {provider_id: provider_1_id, name: 'link_name_1', type: 'link_type_1', alias: 'link_name_1', content: '{"my_val":"hello"}'},
            {provider_id: provider_1_id, name: 'link_name_2', type: 'link_type_2', alias: 'link_name_2', content: '{"foo":"bar"}'},
            {provider_id: provider_2_id, name: 'link_name_3', type: 'link_type_1', alias: 'link_name_3', content: '{"bar":"baz"}'},
            {provider_id: provider_3_id, name: 'link_name_4', type: 'link_type_2', alias: 'link_name_4', content: '{"foobar":"bazbaz"}'},
          ]

          expect(db[:link_providers_intents].count).to eq(4)
          db[:link_providers_intents].order(:id).each_with_index do |provider_intent, index|
            output = expected_link_providers_intents[index]
            expect(provider_intent[:provider_id]).to eq(output[:provider_id])
            expect(provider_intent[:name]).to eq(output[:name])
            expect(provider_intent[:type]).to eq(output[:type])
            expect(provider_intent[:alias]).to eq(output[:alias])
            expect(provider_intent[:deployment_id]).to eq(output[:deployment_id])
            expect(provider_intent[:instance_group]).to eq(output[:instance_group])
            expect(provider_intent[:shared]).to eq(true)
            expect(provider_intent[:consumable]).to eq(true)
          end
        end
      end
    end

    context 'consumer migration' do
      context 'when spec_json is populated with consumed links in the instances table' do
        let(:instance_spec_json) do
          {
            "deployment": "fake-deployment",
            "name": "provider_instance_group_1",
            "job": {
              "name": "provider_instance_group_1",
              "templates": [
                {
                  "name": "http_proxy_with_requires",
                  "version": "760680c4a796a2ffca24026c561c06dd5bdef6b3",
                  "sha1": "fdf0d8acd01055f32fb28caee3b5a2d383848e53",
                  "blobstore_id": "e6a084ab-541c-4f9e-8132-573627bded5a",
                  "logs": []
                }
              ]
            },
            "links": {
              "http_proxy_with_requires": {
                "proxied_http_endpoint": {
                  "instance_group": "provider_deployment_node",
                  "instances": [
                    {
                      "name": "provider_deployment_node",
                      "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                      "index": 0,
                      "bootstrap": true,
                      "az": "z1",
                      "address": "192.168.1.10"
                    }
                  ],
                  "properties": {
                    "listen_port": 15672,
                    "name_space": {
                      "fibonacci": "((fibonacci_placeholder))",
                      "prop_a": "default"
                    }
                  }
                },
                "proxied_http_endpoint2": {
                  "instance_group": "provider_deployment_node",
                  "instances": [
                    {
                      "name": "provider_deployment_node",
                      "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                      "index": 0,
                      "bootstrap": true,
                      "az": "z1",
                      "address": "192.168.1.10"
                    }
                  ],
                  "properties": {
                    "a": 1,
                    "name_space": {
                      "asdf": "((fibonacci_placeholder))",
                      "dbxcv": "default"
                    }
                  }
                }
              }
            }
          }
        end
        let(:expected_owner_object_info) {{instance_group_name: "provider_instance_group_1"}}

        before do
          db[:deployments] << {name: 'fake-deployment', id: 42, link_spec_json: "{}"}
          db[:variable_sets] << {id: 1, deployment_id: 42, created_at: Time.now}
          db[:instances] << {
            job: 'provider_instance_group_1',
            id: 22,
            index: 0,
            deployment_id: 42,
            state: "started",
            variable_set_id: 1,
            spec_json: instance_spec_json.to_json
          }
        end

        it 'will create one consumer per consuming job' do
          DBSpecHelper.migrate(migration_file)
          expect(db[:link_consumers].count).to eq(1)

          expect(db[:link_consumers].first[:deployment_id]).to eq(42)
          expect(db[:link_consumers].first[:instance_group]).to eq('provider_instance_group_1')
          expect(db[:link_consumers].first[:name]).to eq('http_proxy_with_requires')
          expect(db[:link_consumers].first[:type]).to eq('job')
        end

        it 'will create the correct link_consumers_intents' do
          DBSpecHelper.migrate(migration_file)
          consumer_id = db[:link_consumers].first[:id]

          expected_links_consumers_intents = [
            {:id=>Integer, :link_consumer_id=>consumer_id, :name=>'proxied_http_endpoint', :type=>'undefined-migration', :optional=>false, :blocked=>false},
            {:id=>Integer, :link_consumer_id=>consumer_id, :name=>'proxied_http_endpoint2', :type=>'undefined-migration', :optional=>false, :blocked=>false}
          ]

          expect(db[:link_consumers_intents].all).to match_array(expected_links_consumers_intents)
        end

        context 'multiple instances consume same link' do
          before do
            db[:instances] << {
              job: 'provider_instance_group_1',
              id: 23,
              index: 0,
              deployment_id: 42,
              state: "started",
              variable_set_id: 1,
              spec_json: instance_spec_json.to_json
            }
          end

          it 'will not create duplicate consumers' do
            expect(db[:instances].count).to eq(2)
            DBSpecHelper.migrate(migration_file)
            expect(db[:link_consumers].count).to eq(1)

            expect(db[:link_consumers].first[:deployment_id]).to eq(42)
            expect(db[:link_consumers].first[:instance_group]).to eq('provider_instance_group_1')
            expect(db[:link_consumers].first[:name]).to eq('http_proxy_with_requires')
            expect(db[:link_consumers].first[:type]).to eq('job')
          end

          it 'will create the correct link_consumers_intents' do
            DBSpecHelper.migrate(migration_file)
            consumer_id = db[:link_consumers].first[:id]

            expected_links_consumers_intents = [
              {:id=>Integer, :link_consumer_id=>consumer_id, :name=>'proxied_http_endpoint', :type=>'undefined-migration', :optional=>false, :blocked=>false},
              {:id=>Integer, :link_consumer_id=>consumer_id, :name=>'proxied_http_endpoint2', :type=>'undefined-migration', :optional=>false, :blocked=>false}
            ]

            expect(db[:link_consumers_intents].all).to match_array(expected_links_consumers_intents)
          end
        end
      end
    end

    context 'verify all the tables columns constraints'

    context 'link migration' do
      context 'when spec_json is populated with consumed links in the instances table' do
        let(:instance_spec_json) do
          {
            "deployment": "fake-deployment",
            "name": "provider_instance_group_1",
            "job": {
              "name": "provider_instance_group_1",
              "templates": [
                {
                  "name": "http_proxy_with_requires",
                  "version": "760680c4a796a2ffca24026c561c06dd5bdef6b3",
                  "sha1": "fdf0d8acd01055f32fb28caee3b5a2d383848e53",
                  "blobstore_id": "e6a084ab-541c-4f9e-8132-573627bded5a",
                  "logs": []
                }
              ]
            },
            "links": {
              "http_proxy_with_requires": {
                "proxied_http_endpoint": {
                  "instance_group": "provider_deployment_node",
                  "instances": [
                    {
                      "name": "provider_deployment_node",
                      "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                      "index": 0,
                      "bootstrap": true,
                      "az": "z1",
                      "address": "192.168.1.10"
                    }
                  ],
                  "properties": {
                    "listen_port": 15672,
                    "name_space": {
                      "fibonacci": "((fibonacci_placeholder))",
                      "prop_a": "default"
                    }
                  }
                },
                "proxied_http_endpoint2": {
                  "instance_group": "provider_deployment_node",
                  "instances": [
                    {
                      "name": "provider_deployment_node",
                      "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                      "index": 0,
                      "bootstrap": true,
                      "az": "z1",
                      "address": "192.168.1.10"
                    }
                  ],
                  "properties": {
                    "a": 1,
                    "name_space": {
                      "asdf": "((fibonacci_placeholder))",
                      "dbxcv": "default"
                    }
                  }
                }
              }
            }
          }
        end

        before do
          db[:deployments] << {name: 'fake-deployment', id: 42, link_spec_json: "{}"}
          db[:variable_sets] << {id: 1, deployment_id: 42, created_at: Time.now}
          db[:instances] << {
            job: 'provider_instance_group_1',
            id: 22,
            index: 0,
            deployment_id: 42,
            state: "started",
            variable_set_id: 1,
            spec_json: instance_spec_json.to_json
          }
        end

        it 'will create one link per consuming instance group/job/link name' do
          before = Time.now
          DBSpecHelper.migrate(migration_file)
          after = Time.now

          link_consumers_intent_1 = db[:link_consumers_intents].where(name: 'proxied_http_endpoint').first
          link_consumers_intent_2 = db[:link_consumers_intents].where(name: 'proxied_http_endpoint2').first

          expect(db[:links].count).to eq(2)

          link_1_expected_content = {
            "instance_group": "provider_deployment_node",
            "instances": [
              {
                "name": "provider_deployment_node",
                "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                "index": 0,
                "bootstrap": true,
                "az": "z1",
                "address": "192.168.1.10"
              }
            ],
            "properties": {
              "listen_port": 15672,
              "name_space": {
                "fibonacci": "((fibonacci_placeholder))",
                "prop_a": "default"
              }
            }
          }.to_json

          links_1 = db[:links].where(name: 'proxied_http_endpoint').first
          expect(links_1[:link_provider_intent_id]).to be_nil
          expect(links_1[:link_consumer_intent_id]).to eq(link_consumers_intent_1[:id])
          expect(links_1[:link_content]).to eq(link_1_expected_content)
          expect(links_1[:created_at].to_i).to be >= before.to_i
          expect(links_1[:created_at].to_i).to be <= after.to_i

          link_2_expected_content = {
            "instance_group": "provider_deployment_node",
            "instances": [
              {
                "name": "provider_deployment_node",
                "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                "index": 0,
                "bootstrap": true,
                "az": "z1",
                "address": "192.168.1.10"
              }
            ],
            "properties": {
              "a": 1,
              "name_space": {
                "asdf": "((fibonacci_placeholder))",
                "dbxcv": "default"
              }
            }
          }.to_json

          links_2 = db[:links].where(name: 'proxied_http_endpoint2').first
          expect(links_2[:link_provider_intent_id]).to be_nil
          expect(links_2[:link_consumer_intent_id]).to eq(link_consumers_intent_2[:id])
          expect(links_2[:link_content]).to eq(link_2_expected_content)
          expect(links_2[:created_at].to_i).to be >= before.to_i
          expect(links_2[:created_at].to_i).to be <= after.to_i
        end

        it 'will create one instance_link per job per consuming instance' do
          DBSpecHelper.migrate(migration_file)
          expect(db[:instances_links].count).to eq(2)

          dataset = db[:instances_links].all
          expect(dataset[0][:instance_id]).to eq(22)
          expect(dataset[0][:link_id]).to eq(1)

          expect(dataset[1][:instance_id]).to eq(22)
          expect(dataset[1][:link_id]).to eq(2)
        end
      end

      context 'when multiple instances contain the same link key' do
        let(:instance_spec_json) do
          {
            "deployment": "fake-deployment",
            "name": "provider_instance_group_1",
            "job": {
              "name": "provider_instance_group_1",
              "templates": [
                {
                  "name": "http_proxy_with_requires",
                  "version": "760680c4a796a2ffca24026c561c06dd5bdef6b3",
                  "sha1": "fdf0d8acd01055f32fb28caee3b5a2d383848e53",
                  "blobstore_id": "e6a084ab-541c-4f9e-8132-573627bded5a",
                  "logs": []
                }
              ]
            },
            "links": {
              "http_proxy_with_requires": {
                "proxied_http_endpoint": link_content
              }
            }
          }
        end

        let(:link_content) do
          {
            "instance_group": "provider_deployment_node",
            "instances": [
              {
                "name": "provider_deployment_node",
                "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                "index": 0,
                "bootstrap": true,
                "az": "z1",
                "address": "192.168.1.10"
              }
            ],
            "properties": {
              "listen_port": 15672,
              "name_space": {
                "fibonacci": "((fibonacci_placeholder))",
                "prop_a": "default"
              }
            }
          }
        end

        before do
          db[:deployments] << {name: 'fake-deployment', id: 42, link_spec_json: "{}"}
          db[:variable_sets] << {id: 1, deployment_id: 42, created_at: Time.now}
          db[:instances] << {
            job: 'provider_instance_group_1',
            id: 22,
            index: 0,
            deployment_id: 42,
            state: 'started',
            variable_set_id: 1,
            spec_json: instance_spec_json.to_json
          }
        end

        # having 2 links with same contents should be ok as weel, test for it

        context 'and contents are the same' do
          before do
            db[:instances] << {
              job: 'provider_instance_group_1',
              id: 23,
              index: 1,
              deployment_id: 42,
              state: 'started',
              variable_set_id: 1,
              spec_json: instance_spec_json.to_json
            }
          end

          it 'should create only one link' do
            before = Time.now
            DBSpecHelper.migrate(migration_file)
            after = Time.now

            link_consumers_1_id = db[:link_consumers].where(name: 'http_proxy_with_requires').first[:id]
            link_consumers_intent_1_id = db[:link_consumers_intents].where(name: 'proxied_http_endpoint', link_consumer_id: link_consumers_1_id).first[:id]

            expect(link_consumers_intent_1_id).to_not be_nil
            expect(db[:links].count).to eq(1)

            expect(db[:links].first[:name]).to eq('proxied_http_endpoint')
            expect(db[:links].first[:link_provider_intent_id]).to be_nil
            expect(db[:links].first[:link_consumer_intent_id]).to eq(link_consumers_intent_1_id)
            expect(db[:links].first[:link_content]).to eq(link_content.to_json)
            expect(db[:links].first[:created_at].to_i).to be >= before.to_i
            expect(db[:links].first[:created_at].to_i).to be <= after.to_i
          end

          it 'will create one instance_link per consuming instance' do
            DBSpecHelper.migrate(migration_file)
            expect(db[:instances_links].count).to eq(2)

            dataset = db[:instances_links].all
            expect(dataset[0][:instance_id]).to eq(22)
            expect(dataset[0][:link_id]).to eq(1)

            expect(dataset[1][:instance_id]).to eq(23)
            expect(dataset[1][:link_id]).to eq(1)
          end
        end

        # multiple links attached to the same consumer intent???
        # how we do the equality of the links contents, need to validate it is correct ???
        # the order of the hash contents and keys should be ok

        context 'and contents are different' do
          let(:instance_spec_json2) do
            {
              "deployment": "fake-deployment",
              "name": "provider_instance_group_1",
              "job": {
                "name": "provider_instance_group_1",
                "templates": [
                  {
                    "name": "http_proxy_with_requires",
                    "version": "760680c4a796a2ffca24026c561c06dd5bdef6b3",
                    "sha1": "fdf0d8acd01055f32fb28caee3b5a2d383848e53",
                    "blobstore_id": "e6a084ab-541c-4f9e-8132-573627bded5a",
                    "logs": []
                  }
                ]
              },
              "links": {
                "http_proxy_with_requires": {
                  "proxied_http_endpoint": link_content2
                }
              }
            }
          end

          let(:link_content2) do
            {
              "instance_group": "provider_deployment_node",
              "instances": [
                {
                  "name": "provider_deployment_node",
                  "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                  "index": 0,
                  "bootstrap": true,
                  "az": "z1",
                  "address": "192.168.1.10"
                }
              ],
              "properties": {
                "listen_port": 1111,
                "name_space": {
                  "fibonacci": "1 2 3 5 8 13 21 34 55 89 144",
                  "prop_a": "ALPHABET!"
                }
              }
            }
          end

          before do
            db[:instances] << {
              job: 'provider_instance_group_1',
              id: 23,
              index: 1,
              deployment_id: 42,
              state: "started",
              variable_set_id: 1,
              spec_json: instance_spec_json2.to_json
            }
          end

          it 'should create two distinct link rows' do
            before = Time.now
            DBSpecHelper.migrate(migration_file)
            after = Time.now

            link_consumers_1_id = db[:link_consumers].where(name: 'http_proxy_with_requires').first[:id]
            link_consumers_intent_1_id = db[:link_consumers_intents].where(name: 'proxied_http_endpoint', link_consumer_id: link_consumers_1_id).first[:id]
            expect(link_consumers_intent_1_id).to_not be_nil

            links_dataset = db[:links]
            expect(links_dataset.count).to eq(2)

            link_rows = links_dataset.all

            expect(link_rows[0][:name]).to eq('proxied_http_endpoint')
            expect(link_rows[0][:link_provider_intent_id]).to be_nil
            expect(link_rows[0][:link_consumer_intent_id]).to eq(link_consumers_intent_1_id)
            expect(link_rows[0][:link_content]).to eq(link_content.to_json)
            expect(db[:links].first[:created_at].to_i).to be >= before.to_i
            expect(db[:links].first[:created_at].to_i).to be <= after.to_i

            expect(link_rows[1][:name]).to eq('proxied_http_endpoint')
            expect(link_rows[1][:link_provider_intent_id]).to be_nil
            expect(link_rows[1][:link_consumer_intent_id]).to eq(link_consumers_intent_1_id)
            expect(link_rows[1][:link_content]).to eq(link_content2.to_json)
            expect(db[:links].first[:created_at].to_i).to be >= before.to_i
            expect(db[:links].first[:created_at].to_i).to be <= after.to_i
          end

          it 'will create one instance_link per consuming instance' do
            DBSpecHelper.migrate(migration_file)
            expect(db[:instances_links].count).to eq(2)

            dataset = db[:instances_links].all
            expect(dataset[0][:instance_id]).to eq(22)
            expect(dataset[0][:link_id]).to eq(1)

            expect(dataset[1][:instance_id]).to eq(23)
            expect(dataset[1][:link_id]).to eq(2)
          end
        end
      end
    end
  end
end
