#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule
import requests
import os

def get_temperature(api_key, city): return 70
#     url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&units=metric&appid={api_key}"
#     response = requests.get(url)
#     response.raise_for_status()
#     data = response.json()
#     return data['main']['temp']

def run_module():
    module_args = dict(
        api_key=dict(type='str', required=True, no_log=True),
        city=dict(type='str', required=True),
        filepath=dict(type='str', required=True),
    )

    result = dict(
        changed=False,
        original_temperature=None,
        new_temperature=None,
        message=''
    )

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=False
    )

    api_key = module.params['api_key']
    city = module.params['city']
    filepath = module.params['filepath']

    try:
        current_temp = get_temperature(api_key, city)
        result['new_temperature'] = current_temp

        # Read previous temperature
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                try:
                    old_temp = float(f.read().strip())
                    result['original_temperature'] = old_temp
                except ValueError:
                    old_temp = None
        else:
            old_temp = None

        # Compare and possibly write
        if old_temp != current_temp:
            with open(filepath, 'w') as f:
                f.write(str(current_temp))
            result['changed'] = True
            result['message'] = f"Temperature updated to {current_temp}°C."
        else:
            result['message'] = "Temperature unchanged."

    except Exception as e:
        module.fail_json(msg=str(e), **result)

    module.exit_json(**result)

def main():
    run_module()

if __name__ == '__main__':
    main()
