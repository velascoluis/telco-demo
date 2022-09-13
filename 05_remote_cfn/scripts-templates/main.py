import json
import numpy as np


def computeULDL(request):
    try:
        return_value = []
        request_json = request.get_json(silent=True)
        for call in request_json['calls']:
             matrix = np.array(call).reshape((3, 3))
             return_value.append(np.linalg.det(matrix))
        return json.dumps({"replies" : return_value})
    except Exception as e:
        return json.dumps({"errorMessage" :"ERROR"}), 400
