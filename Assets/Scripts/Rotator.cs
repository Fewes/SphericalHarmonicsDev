using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Rotator : MonoBehaviour
{
	private float m_time;

	private void Update()
	{
		m_time += Time.deltaTime;
		transform.localEulerAngles = Vector3.up * Mathf.Sin(m_time * 0.5f) * 180;
	}
}
