using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class SkySetter : MonoBehaviour
{
	public Material sky;

	private void Awake()
	{
		var button = GetComponent<Button>();
		button.onClick.AddListener(Set);
	}

	private void Set()
	{
		RenderSettings.skybox = sky;
		DynamicGI.UpdateEnvironment();
	}
}
