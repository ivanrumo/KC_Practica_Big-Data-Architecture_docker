import requests

from datetime import datetime, timedelta
import time
import os

# obtenemos la fecha de hace 1 dia
d = datetime.today() - timedelta(days=1)

fromdate = int(d.timestamp())

url_base = "https://api.stackexchange.com/2.2/answers?&order=asc&sort=activity&site=stackoverflow&pagesize=100&fromdate=" + str(
    fromdate)
print(url_base)
has_more = True
pagina = 1


with open('data/user_ids_answers', 'w') as f_user_ids_answers:
    while (has_more):
        url_request = url_base + "&page=" + str(pagina)
        response = requests.get(url_request)

        result = response.json()

        if (result.get('error_id')):
            print("Error: " + result.get('error_message'))
            break;

        for answer in result['items']:
            owner = answer['owner']
            if (owner.get('user_id')):  # algunas peticiones no traen el user_id
                f_user_ids_answers.write(str(answer['owner']['user_id']) + "\n")
                #print(str(answer['owner']['user_id']) + "\n")

        print(end=".")
        #print("request")

        has_more = result['has_more']
        pagina = pagina + 1
        time.sleep(1)


with open('data/user_ids_answers', 'r') as f_user_ids_answers:
    # El API de stackexchange nos permite
    # https://api.stackexchange.com/docs/users-by-ids

    i = 0
    users_url = ""
    for user_id in f_user_ids_answers:
        user_id = f_user_ids_answers.readline().rstrip()

        if (i >= 100):
            # quitamos el ultimo ; y hacemos la peticion para obtener los datos de los usuarios
            users_url = users_url[:-1]
            url = "https://api.stackexchange.com/2.2/users/" + users_url + "?pagesize=100&order=desc&sort=reputation&site=stackoverflow"
            # print(url)
            print(end=".")
            response = requests.get(url)
            result = response.json()

            with open('data/user_ids_names', 'a') as f_user_ids_names:
                if (result.get('error_id')):
                    print("Error: " + result.get('error_message'))
                else:
                    for user in result['items']:
                        user_id = user['user_id']
                        name = user.get('display_name')
                        reputation = user.get('reputation')
                        location = user.get('location')
                        f_user_ids_names.write(
                            str(user_id) + "," + name + "," + str(reputation) + "," + str(location) + "\n")

            i = 0
            users_url = ""

        users_url = users_url + str(user_id) + ";"
        i = i + 1


