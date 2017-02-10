require 'spec_helper'

describe Broadside::Configuration do
  include_context 'deploy configuration'

  it 'should be able to find a target' do
    expect { Broadside.config.get_target_by_name!(test_target_name) }.to_not raise_error
  end

  it 'should raise an error when a target is missing' do
    expect { Broadside.config.get_target_by_name!('barf') }.to raise_error(ArgumentError)
  end

  it 'should raise an error when ecs is misconfigured' do
    expect { Broadside.configure { |config| config.aws.region = nil } }.to raise_error(ArgumentError)
    expect { Broadside.configure { |config| config.ecs.poll_frequency = 'poll' } }.to raise_error(ArgumentError)
    expect { Broadside.configure { |config| config.aws.credentials = 'password' } }.to raise_error(ArgumentError)
  end

  describe '#ssh_cmd' do
    let(:ip) { '123.123.123.123' }
    let(:ssh_config) { {} }

    before(:each) do
      Broadside.config.ssh = ssh_config
    end

    it 'should build the SSH command' do
      expect(Broadside.config.ssh_cmd(ip)).to eq("ssh -o StrictHostKeyChecking=no #{ip}")
    end

    context 'with configured SSH user and keyfile' do
      let(:keyfile) { 'path_to_keyfile' }
      let(:ssh_config) { { user: user, keyfile: keyfile } }

      it 'generates an SSH command string with keyfile flag and user set' do
        expect(Broadside.config.ssh_cmd(ip)).to eq(
          "ssh -o StrictHostKeyChecking=no -i #{keyfile} #{user}@#{ip}"
        )
      end

      context 'with tty option' do
        it 'generates an SSH command string with -tt flags' do
          expect(Broadside.config.ssh_cmd(ip, tty: true)).to eq(
            "ssh -o StrictHostKeyChecking=no -t -t -i #{keyfile} #{user}@#{ip}"
          )
        end
      end

      context 'with configured SSH proxy' do
        let(:ssh_proxy_config) { {} }
        let(:ssh_config) do
          {
            user: user,
            keyfile: keyfile,
            proxy: ssh_proxy_config
          }
        end

        it 'is invalid if proxy is incorrectly configured' do
          expect(Broadside.config.valid?).to be false
        end

        context 'with proxy user, host, and port' do
          let(:proxy_user) { 'proxy-user' }
          let(:proxy_host) { 'proxy-host' }
          let(:proxy_port) { 22 }
          let(:ssh_proxy_config) do
            {
              user: proxy_user,
              host: proxy_host,
              port: proxy_port
            }
          end

          it 'generates an SSH command string with the configured SSH proxy' do
            expect(Broadside.config.ssh_cmd(ip)).to eq(
              "ssh -o StrictHostKeyChecking=no -i #{keyfile} -o ProxyCommand=\"ssh -q #{proxy_user}@#{proxy_host} nc #{ip} #{proxy_port}\" #{user}@#{ip}"
            )
          end

          context 'with proxy keyfile' do
            let(:proxy_keyfile) { 'path_to_proxy_keyfile' }
            let(:ssh_proxy_config) do
              {
                user: proxy_user,
                host: proxy_host,
                port: proxy_port,
                keyfile: proxy_keyfile
              }
            end

            it 'generates an SSH command string with the configured SSH proxy' do
              expect(Broadside.config.ssh_cmd(ip)).to eq(
                "ssh -o StrictHostKeyChecking=no -i #{keyfile} -o ProxyCommand=\"ssh -q -i #{proxy_keyfile} #{proxy_user}@#{proxy_host} nc #{ip} #{proxy_port}\" #{user}@#{ip}"
              )
            end
          end
        end
      end
    end
  end
end
